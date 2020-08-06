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
}
