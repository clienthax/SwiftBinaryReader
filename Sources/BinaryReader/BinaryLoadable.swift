/// A datatype that can be loaded using a byte copy
public protocol BinaryLoadable {
	/// Required because of Swift's lack of a mem::uninitialized
	init()
}

/// A datatype that can be converted from a disk format with a specific endianness
public protocol EndianConvertible: BinaryLoadable {
	init(littleEndian value: Self)
	init(bigEndian value: Self)
}

extension UInt8:  EndianConvertible {}
extension  Int8:  EndianConvertible {}
extension UInt16: EndianConvertible {}
extension  Int16: EndianConvertible {}
extension UInt32: EndianConvertible {}
extension  Int32: EndianConvertible {}
extension UInt64: EndianConvertible {}
extension  Int64: EndianConvertible {}
extension Float32: EndianConvertible {
	@inlinable public init(littleEndian value: Float) {
		self.init(bitPattern: UInt32(littleEndian: value.bitPattern))
	}
	@inlinable public init(bigEndian value: Float) {
		self.init(bitPattern: UInt32(bigEndian: value.bitPattern))
	}
}
extension Float64: EndianConvertible {
	@inlinable public init(littleEndian value: Double) {
		self.init(bitPattern: UInt64(littleEndian: value.bitPattern))
	}
	@inlinable public init(bigEndian value: Double) {
		self.init(bitPattern: UInt64(bigEndian: value.bitPattern))
	}
}
