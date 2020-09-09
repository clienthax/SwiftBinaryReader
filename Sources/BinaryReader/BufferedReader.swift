/// A BinaryReader that buffers another BinaryReader to reduce the number of read calls that get sent to it
public struct BufferedReader<Base: BinaryReader>: BinaryReader {
	@usableFromInline var base: Base
	@usableFromInline var bufferOffset: Int
	@usableFromInline var currentIndex: Int
	@usableFromInline let bufferSize: Int
	@usableFromInline var buffer: [UInt8]

	@inlinable public var canSeekBackwards: Bool { base.canSeekBackwards }

	@inlinable var remaining: ArraySlice<UInt8> { buffer[currentIndex...] }

	@discardableResult mutating func refill() throws -> Int {
		let amt = try buffer.withUnsafeMutableBytes { try base.read(into: $0) }
		if amt < buffer.count {
			buffer.removeLast(buffer.count - amt)
		}
		return amt
	}

	@discardableResult mutating func advanceBuffer() throws -> Int {
		bufferOffset += buffer.count
		currentIndex = 0
		return try refill()
	}

	@usableFromInline mutating func refillRead(into target: UnsafeMutableRawBufferPointer) throws -> Int {
		assert(target.count > remaining.count)
		remaining.withUnsafeBytes { ptr in
			target.copyMemory(from: ptr)
		}
		let amtSoFar = remaining.count
		let target = UnsafeMutableRawBufferPointer(rebasing: target.dropFirst(remaining.count))
		if target.count >= buffer.count {
			// Bypass buffer
			let amt = try base.read(into: target)
			bufferOffset += amt
			try advanceBuffer()
			return amt + amtSoFar
		} else {
			let amt = try advanceBuffer()
			if target.count > amt {
				buffer.withUnsafeBytes { target.copyMemory(from: $0) }
				buffer.removeAll()
				bufferOffset += amt
				return amt + amtSoFar
			}
			return try amtSoFar + read(into: target)
		}
	}

	@inlinable public mutating func read(into target: UnsafeMutableRawBufferPointer) throws -> Int {
		guard buffer.count > 0 else { return 0 }
		guard target.count <= remaining.count || buffer.count < bufferSize else {
			return try refillRead(into: target)
		}

		remaining.withUnsafeBytes { ptr in
			target.copyMemory(from: .init(rebasing: ptr.prefix(target.count)))
		}
		let amtRead = min(target.count, remaining.count)
		currentIndex += amtRead
		return amtRead
	}

	@usableFromInline mutating func seekReload(offset: Int, whence: SeekWhence) throws -> Int {
		var location = offset
		if whence == .current {
			location += (currentIndex - buffer.count)
		}
		bufferOffset = try base.seek(offset: location, whence: whence)
		currentIndex = 0
		if buffer.count < bufferSize {
			buffer = try base.readAtMostBytes(bufferSize)
		} else {
			try refill()
		}
		return bufferOffset
	}

	@inlinable public mutating func seek(offset: Int, whence: SeekWhence) throws -> Int {
		if whence == .beginning && offset >= bufferOffset && offset <= bufferOffset + buffer.count {
			currentIndex = offset - bufferOffset
			return tell()
		}
		if whence == .current && offset + currentIndex >= 0 && offset + currentIndex <= buffer.count {
			currentIndex += offset
			return tell()
		}
		return try seekReload(offset: offset, whence: whence)
	}

	@inlinable public func tell() -> Int {
		return bufferOffset + currentIndex
	}

	/// Reads until it hits the end or the given byte is found
	/// - returns: The read data, including the termination byte
	/// - note: For optimal performance, do not use the BufferedReader again before the returned ArraySlice is dropped.  If you need to store it long term, use `Array(reader.readUntil(x))`
	public mutating func readUntil(_ byte: UInt8) throws -> ArraySlice<UInt8> {
		var out = ArraySlice<UInt8>()
		while true {
			if let index = remaining.firstIndex(of: byte) {
				defer { currentIndex = index + 1 }
				if out.isEmpty { return remaining[currentIndex...index] }
				out += remaining[currentIndex...index]
				break
			} else {
				out += remaining
				if buffer.count < bufferSize {
					break
				}
				else {
					try advanceBuffer()
				}
			}
		}
		return out
	}

	/// Create a BufferedReader from the given base array
	/// - parameter bufferSize: The size of buffer to use (larger buffers use more memory but less calls to the base reader's read function)
	@inlinable public init(_ base: Base, bufferSize: Int = 4096) throws {
		self.base = base
		self.bufferSize = bufferSize
		self.bufferOffset = try base.tell()
		self.currentIndex = 0
		self.buffer = try self.base.readAtMostBytes(bufferSize)
	}
}
