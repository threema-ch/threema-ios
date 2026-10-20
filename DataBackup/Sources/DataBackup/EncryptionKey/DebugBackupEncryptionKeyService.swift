import Foundation
import Keychain

public final class DebugBackupEncryptionKeyService: BackupEncryptionKeyServiceProtocol {

    // MARK: - Private types

    private struct FixedRecoveryKeyGenerator: RecoveryKeyGeneratorProtocol {
        func generate() throws -> String {
            DebugBackupEncryptionKeyService.key
        }
    }

    // MARK: - Public properties

    public static let key = String(repeating: "1", count: RecoveryKeyGenerator.defaultLength)

    public var currentKey: BackupEncryptionKey {
        service.currentKey
    }

    // MARK: - Private properties

    private let service: BackupEncryptionKeyService

    // MARK: - Lifecycle

    public init(
        keychainManager: any KeychainManagerProtocol,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = BackupEncryptionKeyService(
            keychainManager: keychainManager,
            recoveryKeyGenerator: FixedRecoveryKeyGenerator(),
            now: now
        )

        if service.currentKey.rawValue != Self.key {
            try? service.renewKey()
        }
    }

    // MARK: - Public methods

    public func renewKey() throws {
        try service.renewKey()
    }

    public func deleteKey() throws {
        try service.deleteKey()
    }

    public func markKeyAsDefault() throws {
        try service.markKeyAsDefault()
    }
}
