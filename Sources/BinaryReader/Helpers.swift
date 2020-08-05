extension Optional {
	@inlinable func unwrapOrThrow(_ error: @autoclosure () -> Error) throws -> Wrapped {
		switch self {
		case .some(let val): return val
		case .none: throw error()
		}
	}
}
