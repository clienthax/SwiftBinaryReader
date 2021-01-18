/// A struct that allows an Array to be used as a BinaryReader
public struct ArrayReader: BinaryReader {
	@usableFromInline var index: Int
	@usableFromInline var array: [UInt8]
	@inlinable var remaining: ArraySlice<UInt8> { array[index...] }

	@inlinable public var canSeekBackwards: Bool { true }

	@inlinable public mutating func read(into target: UnsafeMutableRawBufferPointer) throws -> Int {
		if target.count >= remaining.count {
			remaining.withUnsafeBytes { target.copyMemory(from: $0) }
			defer { index = array.count }
			return remaining.count
		} else {
			remaining.withUnsafeBytes { target.copyMemory(from: .init(rebasing: $0.prefix(target.count))) }
			index += target.count
			return target.count
		}
	}

	@inlinable public mutating func seek(offset: Int, whence: SeekWhence) throws -> Int {
		switch whence {
		case .beginning:
			index = offset
		case .current:
			index += offset
		case .end:
			index = array.count + offset
		}
		index = max(0, min(array.count, index))
		return index
	}

	@inlinable public func tell() throws -> Int {
		return index
	}

	@inlinable public mutating func readUntil(_ byte: UInt8) -> ArraySlice<UInt8> {
		if let i = remaining.firstIndex(of: byte) {
			defer { index = i + 1 }
			return remaining[...i]
		}
		defer { index = array.count }
		return remaining
	}

	@inlinable public init(_ array: [UInt8]) {
		self.array = array
		self.index = 0
	}
}

extension ArrayReader: BinaryWriter {
	@inlinable public var currentArray: [UInt8] { return array }

	@inlinable public mutating func write(from buffer: UnsafeRawBufferPointer) {
		let space = array.count - index
		if buffer.count <= space {
			array.withUnsafeMutableBytes { ptr in
				let target = UnsafeMutableRawBufferPointer(rebasing: ptr[index ..< index+buffer.count])
				buffer.copyBytes(to: target)
			}
			index += buffer.count
		} else if space > 0 {
			write(from: .init(rebasing: buffer[..<space]))
			write(from: .init(rebasing: buffer[space...]))
		} else {
			array.append(contentsOf: buffer)
			index = array.count
		}
	}

	@inlinable public var canSeek: Bool { return true }

	@inlinable public mutating func flush() {}

	@inlinable public mutating func truncate() {
		if index != array.count {
			array.removeSubrange(index...)
		}
	}

	@inlinable public init() { self.init([]) }
}
