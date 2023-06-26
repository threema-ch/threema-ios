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

extension FileMessageEntity: MessageAccessibility {
        
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
        switch fileMessageType {
        case .image:
            return BundleUtil.localizedString(forKey: "accessibility_imageMessage_hint")
        case .video:
            return BundleUtil.localizedString(forKey: "accessibility_videoMessage_hint")
        case .sticker:
            return nil // No interaction
        case .animatedSticker:
            return BundleUtil.localizedString(forKey: "accessibility_animatedStickerMessage_hint")
        case .animatedImage:
            return BundleUtil.localizedString(forKey: "accessibility_animatedImageMessage_hint")
        case .file:
            return BundleUtil.localizedString(forKey: "accessibility_fileMessage_hint")
        case .voice:
            return nil // Handled on cell
        }
    }
    
    public var customAccessibilityTrait: UIAccessibilityTraits {
        switch fileMessageType {
        case .image, .animatedImage, .animatedSticker:
            return [.button, .image]
        case .video, .voice:
            return [.button, .playsSound, .startsMediaSession]
        case .file:
            return [.button, .staticText]
        case .sticker:
            return .image
        }
    }
    
    public var accessibilityMessageTypeDescription: String {
        switch fileMessageType {
        case .image:
            return BundleUtil.localizedString(forKey: "accessibility_imageMessage_description")
        case .video:
            return BundleUtil.localizedString(forKey: "accessibility_videoMessage_description")
        case .sticker, .animatedSticker:
            return BundleUtil.localizedString(forKey: "accessibility_stickerMessage_description")
        case .animatedImage:
            return BundleUtil.localizedString(forKey: "accessibility_animatedImageMessage_description")
        case .file:
            return BundleUtil.localizedString(forKey: "accessibility_fileMessage_description")
        case .voice:
            return BundleUtil.localizedString(forKey: "accessibility_voiceMessage_description")
        }
    }
}
