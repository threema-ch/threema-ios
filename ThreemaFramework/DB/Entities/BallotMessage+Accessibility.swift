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

extension BallotMessage: MessageAccessibility {
    public var privateCustomAccessibilityLabel: String {
        guard let ballot else {
            return ""
        }

        if !ballot.isClosed() {
            return String.localizedStringWithFormat(
                #localize("accessibility_poll_content_open"),
                #localize("accessibility_poll_open"),
                ballot.title,
                ballot.localizedMessageSecondaryText().string
            )
        }
        else {
            return String.localizedStringWithFormat(
                #localize("accessibility_poll_content_open"),
                #localize("accessibility_poll_closed"),
                ballot.title,
                ballot.localizedClosingMessageText
            )
        }
    }
    
    public var customAccessibilityHint: String? {
        guard let ballot else {
            return nil
        }

        if ballot.isClosed() {
            return #localize("accessibility_ballotMessage_hint_closed")
        }
        else {
            return #localize("accessibility_ballotMessage_hint_open")
        }
    }

    public var customAccessibilityTrait: UIAccessibilityTraits {
        [.button, .staticText]
    }
    
    public var accessibilityMessageTypeDescription: String {
        #localize("accessibility_pollMessage_description")
    }
}
