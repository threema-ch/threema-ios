import Foundation
import ThreemaProtocols

extension Sync_Contact {
    var createdAtNullable: UInt64? {
        hasCreatedAt ? valueNullable(value: createdAt) : nil
    }

    var firstNameNullable: String? {
        hasFirstName ? valueNullable(value: firstName) : nil
    }

    var lastNameNullable: String? {
        hasLastName ? valueNullable(value: lastName) : nil
    }

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
