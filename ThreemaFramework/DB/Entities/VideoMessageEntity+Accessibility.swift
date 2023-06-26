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

extension VideoMessageEntity: MessageAccessibility {
    public var customAccessibilityLabel: String {
        var text = ""
        
        if let caption {
            text =
                "\(String.localizedStringWithFormat(BundleUtil.localizedString(forKey: "accessibility_caption"), caption))."
        }
        
        return text
    }
    
    public var customAccessibilityValue: String? {
        guard let duration = durationTimeInterval, duration > 0.0 else {
            return nil
        }
        
        let formattedDuration = DateFormatter.timeFormatted(Int(duration))
        return String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "accessibility_file_duration"),
            formattedDuration
        )
    }
    
    public var customAccessibilityHint: String? {
        BundleUtil.localizedString(forKey: "accessibility_videoMessage_hint")
    }
    
    public var customAccessibilityTrait: UIAccessibilityTraits {
        [.button, .playsSound, .startsMediaSession]
    }
    
    public var accessibilityMessageTypeDescription: String {
        BundleUtil.localizedString(forKey: "accessibility_videoMessage_description")
    }
}
