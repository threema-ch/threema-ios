import Foundation

/// The recovery key used to encrypt local data backups, together with its lifecycle state.
///
/// Exactly one recovery key exists in the keychain at any time:
/// - A newly generated key is stored in the keychain and starts as `generated`. Generating a new
///   key replaces any previously stored key.
/// - Once a backup completes successfully with the key, it becomes the `default` key — the key
///   that will be reused for the next backup — and records the date of that backup.
public enum BackupEncryptionKey: Sendable {

    /// The key is not yet resolved
    case none

    /// A freshly generated key, usable for the next backup (not yet stored in the Keychain).
    case generated(key: String)

    /// A key that has been used for at least one successful backup and is the default key for
    /// the next backup, along with the date of that most recent successful backup.
    case `default`(key: String, lastBackupDate: Date)

    /// The recovery key value, independent of lifecycle state.
    public var rawValue: String {
        switch self {
        case let .generated(key), let .default(key, _):
            key

        case .none:
            ""
        }
    }

    public var isDefault: Bool {
        switch self {
        case .default:
            true
        case .generated, .none:
            false
        }
    }

    /// Date of the most recent successful backup made with this key, or `nil` if the key has not
    /// yet been used for a backup.
    public var lastBackupDate: Date? {
        switch self {
        case .none, .generated:
            nil
        case let .default(_, lastBackupDate):
            lastBackupDate
        }
    }
}

#if DEBUG
    extension BackupEncryptionKey {
        public static var mockNone: Self {
            .none
        }

        public static var mockGeneratedKey: Self {
            .generated(key: String(repeating: "A1B2C3D4", count: 8))
        }

        public static var mockDefaultKey: Self {
            .default(
                key: String(repeating: "A1B2C3D4", count: 8),
                lastBackupDate: Date(timeIntervalSince1970: 1_234_567_890)
            )
        }
    }
#endif
