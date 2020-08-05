import Foundation

extension SeekWhence {
	var toUnix: Int32 {
		switch self {
		case .beginning: return SEEK_SET
		case .current:   return SEEK_CUR
		case .end:       return SEEK_END
		}
	}
}

/// The error returned from a unix C function
public struct UnixError: LocalizedError {
	public var code: Int32

	init() {
		code = errno
	}

	static func negativeIsError<N: SignedInteger>(_ n: N) throws -> N {
		if n >= 0 {
			return n
		} else {
			throw UnixError()
		}
	}

	public var errorDescription: String? {
		let ptr = UnsafeMutablePointer<CChar>.allocate(capacity: 64)
		defer { ptr.deallocate() }
		if strerror_r(code, ptr, 64) == 0 {
			return String(cString: ptr)
		} else {
			return "Unknown unix error (code \(code))"
		}
	}
}

/// A BinaryReader for reading files
/// Does not buffer
/// Use a BufferedReader if you want buffering
public class FileReader: BinaryReader {
	public private(set) var fd: Int32

	/// Takes ownership of the given file descripter, closing it on release
	public init(takingOwnershipOfFD fd: Int32) {
		self.fd = fd
	}

	/// Open the given path for reading
	public init(path: String) throws {
		fd = try UnixError.negativeIsError(open(path, O_RDONLY))
	}

	/// Removes the file descriptor from the FileReader, returning it
	/// The FileReader will not close the fd after this
	/// Any further actions on the FileReader will fail
	public func stealFD() -> Int32 {
		defer { fd = -1 }
		return fd
	}

	deinit {
		if fd > 0 {
			close(fd)
		}
	}

	public func read(into target: UnsafeMutableRawBufferPointer) throws -> Int {
		var total = 0
		var target = target
		while !target.isEmpty {
			let amt = Foundation.read(fd, target.baseAddress, target.count)
			guard amt > 0 else {
				if amt == 0 { break }
				if errno == EINTR { continue }
				throw UnixError()
			}
			total += amt
			target = .init(rebasing: target[amt...])
		}
		return total
	}

	public func seek(offset: Int, whence: SeekWhence) throws -> Int {
		return Int(try UnixError.negativeIsError(lseek(fd, off_t(offset), whence.toUnix)))
	}

	public func tell() throws -> Int {
		return try seek(offset: 0, whence: .current)
	}
}
