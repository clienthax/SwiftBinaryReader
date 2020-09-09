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

	init(_ array: [UInt8]) {
		self.array = array
		self.index = 0
	}
}
