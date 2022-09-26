//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation

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
