public protocol BinaryWriter: Seekable {
	/// Write bytes from buffer into the writer
	/// - throws: If the bytes are unable to be written
	mutating func write(from buffer: UnsafeRawBufferPointer) throws

	/// Whether the writer can seek
	var canSeek: Bool { get }

	/// Guarantee that all data has been written to the target output
	mutating func flush() throws

	/// Delete contents of file from the current write position onwards
	mutating func truncate() throws
}

extension BinaryWriter {
	/// Write the given value to the stream in host endianness
	@inlinable public mutating func writeRaw<T: BinaryLoadable>(_ value: T) throws {
		try withUnsafeBytes(of: value) { ptr in
			try write(from: ptr)
		}
	}
	/// Write the given value to the stream, converting it from machine native to disk endianness before writing
	@inlinable public mutating func write<T: SingleEndian>(_ value: T) throws {
		try writeRaw(value.diskEndian)
	}
	/// Write the given value to the stream, converting it from machine native to little endian before writing
	@inlinable public mutating func writeLE<T: EndianConvertible>(_ value: T) throws {
		try writeRaw(value.littleEndian)
	}
	/// Write the given value to the stream, converting it from machine native to big endian before writing
	@inlinable public mutating func writeBE<T: EndianConvertible>(_ value: T) throws {
		try writeRaw(value.bigEndian)
	}
	/// Write the contents of the given byte array to the stream
	@inlinable public mutating func write(_ value: [UInt8]) throws {
		try value.withUnsafeBytes { try write(from: $0) }
	}
	/// Write the given string to the stream as null-terminated UTF-8
	@inlinable public mutating func writeNullTerminated(_ value: inout String) throws {
		try value.withUTF8 { data in
			try write(from: UnsafeRawBufferPointer(data))
			try write(0 as UInt8)
		}
	}
}
