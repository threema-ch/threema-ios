extension Optional {
    public func getOrThrow(_ error: some Error) throws -> Wrapped {
        if let value = self {
            return value
        }
        else {
            throw error
        }
    }
}
