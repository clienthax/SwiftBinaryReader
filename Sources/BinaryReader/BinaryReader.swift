/// An error that indicates that the end of the stream was hit
public struct EndOfStreamError: Error {
	@inlinable init() {}
}

/// A starting location for a seek
public enum SeekWhence {
	case beginning
	case current
	case end
}

public protocol BinaryReader {
	/// Read up to `target.count` bytes into `target`
	/// - returns: The actual number of bytes read.  A number less than `target.count` (including 0) indicates the end of the stream was hit
	/// - throws: If an error other than hitting the end of the stream occurs
	mutating func read(into target: UnsafeMutableRawBufferPointer) throws -> Int
	/// Seek to the given location, clamped to the beginning/end of the stream
	/// - returns: The offset into the file after seeking
	/// - note: Some streams may not support seeking backwards.  They will throw an error in this case
	@discardableResult mutating func seek(offset: Int, whence: SeekWhence) throws -> Int
	/// - returns: The current byte offset into the stream
	func tell() throws -> Int
	/// Whether the reader can seek backwards
	var canSeekBackwards: Bool { get }
	/// Read until a specific byte is found
	mutating func readUntil(_ byte: UInt8) throws -> ArraySlice<UInt8>
}

extension BinaryReader {
	// Default implementations
	@inlinable public var canSeekBackwards: Bool { return false }

	@inlinable public mutating func readUntil(_ byte: UInt8) throws -> ArraySlice<UInt8> {
		var out = [UInt8]()
		while true {
			guard let next: UInt8 = try read() else { break }
			out.append(next)
			if next == byte { break }
		}
		return out[...]
	}
}

extension BinaryReader {
	/// Seek to the given offset from the beginning of the stream
	@inlinable public mutating func seek(to location: Int) throws { try seek(offset: location, whence: .beginning) }
	/// Read the given type from the stream in host endianness
	/// - returns: nil if there wasn't enough data in the stream, otherwise the read value
	@inlinable public mutating func readRaw<Output: BinaryLoadable>(_ type: Output.Type = Output.self) throws -> Output? {
		var output = Output()
		let ok = try withUnsafeMutableBytes(of: &output) { ptr in
			return try read(into: ptr) == ptr.count
		}
		return ok ? output : nil
	}
	/// Read the given type, converting it from the disk endianness to machine native
	/// - returns: nil if there wasn't enough data in the stream, otherwise the read value
	@inlinable public mutating func read<Output: SingleEndian>(_ type: Output.Type = Output.self) throws -> Output? {
		return try readRaw().map { Output(diskEndian: $0) }
	}
	/// Read the given type, converting it from the stream's little endian format to machine native
	/// - returns: nil if there wasn't enough data in the stream, otherwise the read value
	@inlinable public mutating func readLE<Output: EndianConvertible>(_ type: Output.Type = Output.self) throws -> Output? {
		return try readRaw().map { Output(littleEndian: $0) }
	}
	/// Read the given type, converting it from the stream's big endian format to machine native
	/// - returns: nil if there wasn't enough data in the stream, otherwise the read value
	@inlinable public mutating func readBE<Output: EndianConvertible>(_ type: Output.Type = Output.self) throws -> Output? {
		return try readRaw().map { Output(bigEndian: $0) }
	}
	/// Read the given type from the stream in host endianness
	/// - throws: an `EndOfStreamError` if the stream ends, in addition to other read errors
	@inlinable public mutating func forceReadRaw<Output: BinaryLoadable>(_ type: Output.Type = Output.self) throws -> Output {
		return try readRaw().unwrapOrThrow(EndOfStreamError())
	}
	/// Read the given type, converting it from the disk endianness to machine native
	/// - throws: an `EndOfStreamError` if the stream ends, in addition to other read errors
	@inlinable public mutating func forceRead<Output: SingleEndian>(_ type: Output.Type = Output.self) throws -> Output {
		return try read().unwrapOrThrow(EndOfStreamError())
	}
	/// Read the given type, converting it from the stream's little endian format to machine native
	/// - throws: an `EndOfStreamError` if the stream ends, in addition to other read errors
	@inlinable public mutating func forceReadLE<Output: EndianConvertible>(_ type: Output.Type = Output.self) throws -> Output {
		return try readLE().unwrapOrThrow(EndOfStreamError())
	}
	/// Read the given type, converting it from the stream's big endian format to machine native
	/// - throws: an `EndOfStreamError` if the stream ends, in addition to other read errors
	@inlinable public mutating func forceReadBE<Output: EndianConvertible>(_ type: Output.Type = Output.self) throws -> Output {
		return try readBE().unwrapOrThrow(EndOfStreamError())
	}

	/// Reads the requested number of bytes from the stream, or less if the stream ends first
	@inlinable public mutating func readAtMostBytes(_ n: Int) throws -> [UInt8] {
		return try Array(unsafeUninitializedCapacity: n) { (buffer, count) in
			let shortened = UnsafeMutableBufferPointer(rebasing: buffer[..<n])
			count = try read(into: UnsafeMutableRawBufferPointer(shortened))
		}
	}
	/// Reads the requested number of bytes from the stream, or returns nil if the stream ends first
	@inlinable public mutating func readBytes(_ n: Int) throws -> [UInt8]? {
		let out = try readAtMostBytes(n)
		return out.count == n ? out : nil
	}
	/// Reads the requested number of bytes from the stream
	/// - throws: an `EndOfStreamError` if the stream ends
	@inlinable public mutating func forceReadBytes(_ n: Int) throws -> [UInt8] {
		return try readBytes(n).unwrapOrThrow(EndOfStreamError())
	}
	/// Reads to the end of the stream
	@inlinable public mutating func readAll() throws -> [UInt8] {
		if canSeekBackwards {
			let cur = try tell()
			try seek(offset: 0, whence: .end)
			let len = try tell()
			try seek(offset: cur, whence: .beginning)
			return try readAtMostBytes(len - cur)
		}
		var readLen = 4096
		var out = try readAtMostBytes(readLen)
		if out.count < readLen { return out }
		var buffers: [[UInt8]] = []
		while true {
			readLen *= 2
			let next = try readAtMostBytes(readLen)
			buffers.append(next)
			if next.count < readLen { break }
		}
		out.reserveCapacity(out.count + buffers.reduce(0, { $0 + $1.count }))
		for buffer in buffers {
			out.append(contentsOf: buffer)
		}
		return out
	}

	/// Reads until the given byte is hit, then decodes the result as a UTF-8 string
	@inlinable public mutating func readStringUntil(_ byte: UInt8, includingTerminator: Bool = true) throws -> String {
		let read = try readUntil(byte)
		if includingTerminator || read.last != byte {
			return String(decoding: read, as: UTF8.self)
		} else {
			return String(decoding: read.dropLast(), as: UTF8.self)
		}
	}

	/// Reads a null terminated string
	@inlinable public mutating func readNullTerminatedString() throws -> String {
		return try readStringUntil(0, includingTerminator: false)
	}
}
