import Foundation
import ThreemaProtocols

extension Sync_UserProfile {
    var nicknameNullable: String? {
        hasNickname ? valueNullable(value: nickname) : nil
    }

    private func valueNullable<T>(value: T) -> T? {
        if let value = value as? String {
            return value != "" ? value as! T? : nil
        }
        else if let value = value as? UInt64 {
            return value != 0 ? value as! T? : nil
        }
        fatalError("Type not supported")
    }
}

extension Sync_UserProfile.IdentityLinks.IdentityLink {
    var phoneNumberNullable: String? {
        valueNullable(value: phoneNumber)
    }

    var emailNullable: String? {
        valueNullable(value: email)
    }

    private func valueNullable<T>(value: T) -> T? {
        if let value = value as? String {
            return value != "" ? value as! T? : nil
        }
        else if let value = value as? UInt64 {
            return value != 0 ? value as! T? : nil
        }
        fatalError("Type not supported")
    }
}
