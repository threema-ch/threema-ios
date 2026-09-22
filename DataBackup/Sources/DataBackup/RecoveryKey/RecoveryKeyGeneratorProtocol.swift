public protocol RecoveryKeyGeneratorProtocol: Sendable {
    /// Generates a new recovery key.
    func generate() throws -> String
}
