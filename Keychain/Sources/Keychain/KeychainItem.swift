import Foundation
import ThreemaEssentials

enum KeychainItem: CaseIterable {
    case remoteSecret(_ version: KeychainVersion = .v1)
    case identity(_ version: KeychainVersion = .v1)
    case identityBackup(_ version: KeychainVersion = .v1)
    case deviceCookie(_ version: KeychainVersion = .v1)
    case multiDeviceGroupKey(_ version: KeychainVersion = .v1)
    case multiDeviceID(_ version: KeychainVersion = .v1)
    case forwardSecurityWrappingKey(_ version: KeychainVersion = .v1)
    case license(_ version: KeychainVersion = .v1)
    case threemaSafeKey(_ version: KeychainVersion = .v1)
    case threemaSafeServer(_ version: KeychainVersion = .v1)

    static let allCases: [KeychainItem] = [
        .remoteSecret(),
        .identity(),
        .identityBackup(),
        .deviceCookie(),
        .multiDeviceGroupKey(),
        .multiDeviceID(),
        .forwardSecurityWrappingKey(),
        .license(),
        .threemaSafeKey(),
        .threemaSafeServer(),
    ]
    
    /// The label must be unique!
    var label: String {
        // Naming scheme: "Threema" + name where each word is capitalized + version (e.g. "v1")
        switch self {
        case .remoteSecret:
            "Threema Remote Secret v1"
        case .identity:
            // This cannot be changed, because the `KeychainMigration` runs
            // within the `AppMigration`. And the `AppMigration` needs the identity!
            "Threema identity 1"
        case let .identityBackup(version):
            switch version {
            case .v0: "Threema identity backup"
            case .v1: "Threema Identity Backup v1"
            }
        case let .deviceCookie(version):
            switch version {
            case .v0: "Threema device cookie"
            case .v1: "Threema Device Cookie v1"
            }
        case let .multiDeviceGroupKey(version):
            switch version {
            case .v0: "Threema Device Group Key 1"
            case .v1: "Threema Multi Device Group Key v1"
            }
        case .multiDeviceID:
            "Threema Multi Device ID v1"
        case let .forwardSecurityWrappingKey(version):
            switch version {
            case .v0: "Threema FS wrapping key"
            case .v1: "Threema FS Wrapping Key v1"
            }
        case .license:
            "Threema License v1"
        case let .threemaSafeKey(version):
            switch version {
            case .v0: "Threema Safe Key"
            case .v1: "Threema Safe Key v1"
            }
        case let .threemaSafeServer(version):
            switch version {
            case .v0: "Threema Safe Server"
            case .v1: "Threema Safe Server v1"
            }
        }
    }

    var accessibility: CFString {
        switch self {
        case .remoteSecret, .license:
            kSecAttrAccessibleAfterFirstUnlock
        case .identityBackup:
            kSecAttrAccessibleWhenUnlocked
        default:
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }

    var mightContainEncryptedData: Bool {
        switch self {
        case .remoteSecret,
             .identityBackup:
            false
            
        case .identity,
             .deviceCookie,
             .multiDeviceGroupKey,
             .multiDeviceID,
             .forwardSecurityWrappingKey,
             .license,
             .threemaSafeKey,
             .threemaSafeServer:
            true
        }
    }
}

// MARK: - CustomStringConvertible

extension KeychainItem: CustomStringConvertible {
    var description: String {
        label
    }
}
