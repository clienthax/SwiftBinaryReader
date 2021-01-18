import XCTest
@testable import BinaryReader

final class BinaryReaderTests: XCTestCase {
	func testArrayReader() {
		var reader = ArrayReader([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
		XCTAssertEqual(try reader.read(UInt8.self), 0)
		XCTAssertEqual(try reader.readBE(UInt16.self), 0x0102)
		XCTAssertEqual(try reader.readLE(UInt32.self), 0x06050403)
		XCTAssertEqual(try reader.readAtMostBytes(32), [7, 8, 9, 10, 11, 12, 13, 14, 15])
		XCTAssertNoThrow(try reader.seek(to: 0))
		XCTAssertEqual(try reader.readBytes(4), [0, 1, 2, 3])
		XCTAssertThrowsError(try reader.forceReadBytes(16))
		XCTAssertNoThrow(try reader.seek(offset: -6, whence: .end))
		XCTAssertEqual(try reader.forceReadBE(UInt32.self), 0x0a0b0c0d)
		XCTAssertNoThrow(try reader.seek(offset: -6, whence: .current))
		XCTAssertEqual(try reader.forceReadLE(UInt16.self), 0x0908)
		XCTAssertEqual(try reader.readAll(), [10, 11, 12, 13, 14, 15])
		XCTAssertEqual(try reader.readAtMostBytes(4), [])
	}

	func testArrayWriter() {
		var writer = ArrayReader()
		try! writer.write(3 as UInt8)
		XCTAssertEqual(writer.currentArray, [3])
		try! writer.writeLE(3 as UInt32)
		XCTAssertEqual(writer.currentArray, [3, 3, 0, 0, 0])
		try! writer.write([0, 1, 2, 3])
		XCTAssertEqual(writer.currentArray, [3, 3, 0, 0, 0, 0, 1, 2, 3])
		try! writer.seek(to: 3)
		try! writer.writeBE(4 as UInt32)
		XCTAssertEqual(writer.currentArray, [3, 3, 0, 0, 0, 0, 4, 2, 3])
	}

	func testBufferedReader() {
		var reader: BufferedReader<ArrayReader>!
		let base = (0..<65536).map { UInt8(truncatingIfNeeded: $0) }
		XCTAssertNoThrow(reader = try BufferedReader(ArrayReader(base)))
		XCTAssertEqual(try reader.readLE(UInt32.self), 0x03020100)
		XCTAssertNoThrow(try reader.seek(offset: -4, whence: .end))
		XCTAssertEqual(try reader.read(), 252 as UInt8)
		XCTAssertNoThrow(try reader.seek(offset: -1, whence: .current))
		XCTAssertEqual(try reader.read(), 252 as UInt8)
		XCTAssertNoThrow(try reader.seek(offset: -4, whence: .current))
		XCTAssertEqual(try reader.readAtMostBytes(64), [249, 250, 251, 252, 253, 254, 255])
		XCTAssertNoThrow(try reader.seek(offset: 8, whence: .beginning))
		XCTAssertEqual(try reader.forceReadBytes(10), Array(8..<18))
		XCTAssertEqual(try reader.forceReadBytes(10000), Array(base[18..<10018]))
		XCTAssertNoThrow(try reader.seek(offset: -10, whence: .current))
		XCTAssertEqual(try reader.forceReadBytes(10), Array(base[10008..<10018]))
		XCTAssertEqual(try reader.forceReadBytes(5000), Array(base[10018..<15018]))
	}

	static var allTests = [
		("array reader", testArrayReader),
		("buffered reader", testBufferedReader),
	]
}
