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

    public var trimmedValue: String {
        let key = rawValue

        guard key.count > 8 else {
            return key
        }

        return "\(key.prefix(4))...\(key.suffix(4))"
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

        /// Mock key for previews and tests, split into groups so it isn't mistaken for a real secret
        private static let sampleKey = [
            "45S9KSPB", "6JVQZ12Y", "99BX8MS7", "44Y4HNJS",
            "X19HQ7C4", "A7Q4WSZU", "722X789T", "745QT418",
        ].joined()

        private static let date = Date(timeIntervalSince1970: 1_234_567_890)

        public static var mockNone: Self {
            .none
        }

        public static var mockGeneratedKey: Self {
            .generated(key: sampleKey)
        }

        public static var mockDefaultKey: Self {
            .default(key: sampleKey, lastBackupDate: date)
        }
    }
#endif
