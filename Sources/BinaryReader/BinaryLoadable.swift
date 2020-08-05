/// A datatype that can be loaded using a byte copy
/// - note: Types whose sizes vary by platform (e.g. `Int` or `CGFloat`) should not be `BinaryLoadable`
public protocol BinaryLoadable {
	/// Required because of Swift's lack of a mem::uninitialized
	init()
}

/// A datatype that can be converted from a disk format with a specific endianness
public protocol EndianConvertible: BinaryLoadable {
	init(littleEndian value: Self)
	init(bigEndian value: Self)
	var littleEndian: Self { get }
	var bigEndian: Self { get }
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
	@inlinable public init(littleEndian value: Float32) {
		self.init(bitPattern: UInt32(littleEndian: value.bitPattern))
	}
	@inlinable public init(bigEndian value: Float32) {
		self.init(bitPattern: UInt32(bigEndian: value.bitPattern))
	}

	@inlinable public var littleEndian: Float32 {
		Float32(bitPattern: bitPattern.littleEndian)
	}
	@inlinable public var bigEndian: Float32 {
		Float32(bitPattern: bitPattern.bigEndian)
	}
}
extension Float64: EndianConvertible {
	@inlinable public init(littleEndian value: Float64) {
		self.init(bitPattern: UInt64(littleEndian: value.bitPattern))
	}
	@inlinable public init(bigEndian value: Float64) {
		self.init(bitPattern: UInt64(bigEndian: value.bitPattern))
	}

	@inlinable public var littleEndian: Float64 {
		Float64(bitPattern: bitPattern.littleEndian)
	}
	@inlinable public var bigEndian: Float64 {
		Float64(bitPattern: bitPattern.bigEndian)
	}
}

/// A datatype that is either always stored with the same endianness, or is the same in both endiannesses
public protocol SingleEndian: BinaryLoadable {
	init(diskEndian value: Self)
	var diskEndian: Self { get }
}

extension UInt8: SingleEndian {
	@inlinable public init(diskEndian value: UInt8) { self.init(value) }
	@inlinable public var diskEndian: UInt8 { self }
}

extension Int8: SingleEndian {
	@inlinable public init(diskEndian value: Int8) { self.init(value) }
	@inlinable public var diskEndian: Int8 { self }
}
