//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

extension BallotMessage: MessageAccessibility {
    public var customAccessibilityLabel: String {
        guard let ballot else {
            return ""
        }

        if !ballot.isClosed() {
            return String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "accessibility_poll_content_open"),
                BundleUtil.localizedString(forKey: "accessibility_poll_open"),
                ballot.title,
                ballot.localizedMessageSecondaryText().string
            )
        }
        else {
            return String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "accessibility_poll_content_open"),
                BundleUtil.localizedString(forKey: "accessibility_poll_closed"),
                ballot.title,
                ballot.localizedClosingMessageText
            )
        }
    }
    
    public var customAccessibilityHint: String? {
        guard let ballot else {
            return ""
        }

        if ballot.isClosed() {
            return BundleUtil.localizedString(forKey: "accessibility_ballotMessage_hint_closed")
        }
        else {
            return BundleUtil.localizedString(forKey: "accessibility_ballotMessage_hint_open")
        }
    }

    public var customAccessibilityTrait: UIAccessibilityTraits {
        [.button, .staticText]
    }
    
    public var accessibilityMessageTypeDescription: String {
        BundleUtil.localizedString(forKey: "accessibility_pollMessage_description")
    }
}
