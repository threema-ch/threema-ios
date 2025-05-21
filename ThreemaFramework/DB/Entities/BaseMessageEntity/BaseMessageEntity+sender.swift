//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaMacros

extension BaseMessageEntity {
    
    /// Readable name of the sender
    @objc public var localizedSenderName: String {
        if isOwnMessage {
            #localize("me")
        }
        else {
            if let sender {
                sender.displayName
            }
            else {
                conversation.contact?.displayName ?? ""
            }
        }
    }
    
    public var senderIDColor: UIColor {
        if isOwnMessage {
            MyIdentityStore.shared().idColor
        }
        else {
            if let sender {
                sender.idColor
            }
            else {
                conversation.contact?.idColor ?? .primary
            }
        }
    }
}
