//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
import ThreemaFramework
import ThreemaMacros

class ShareExtensionHelpers {
    static func getDescription(for conversations: [ConversationEntity]) -> NSAttributedString {
        let attrString = NSMutableAttributedString(
            string: ShareExtensionHelpers.getRecipientListHeading(for: conversations),
            attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline)]
        )

        let convListAttrString = NSAttributedString(
            string: ShareExtensionHelpers.getRecipientListDescription(for: conversations),
            attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        
        attrString.append(convListAttrString)
        
        return attrString
    }
    
    static func getRecipientListHeading(for conversations: [ConversationEntity]) -> String {
        "\(#localize("sending_to")) (\(conversations.count)) : "
    }
    
    static func getRecipientListDescription(for conversations: [ConversationEntity]) -> String {
        var convDescriptionString = ""
        var second = false
        
        for conversation in conversations {
            if second {
                convDescriptionString.append(", ")
            }

            convDescriptionString.append(conversation.displayName)

            second = true
        }
        
        return convDescriptionString
    }
}
