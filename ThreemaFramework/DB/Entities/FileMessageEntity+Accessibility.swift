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
        
    public var privateCustomAccessibilityLabel: String {
        
        var text = ""
        
        if let caption {
            text =
                "\(String.localizedStringWithFormat(BundleUtil.localizedString(forKey: "accessibility_caption"), caption))."
        }
        
        return text
    }
    
    public var customAccessibilityValue: String? {
        var customValue: String?
        switch fileMessageType {
        case .voice:
            if !isOwnMessage,
               consumed == nil {
                // If a voice message hasn't been played yet, add the accessibility info
                customValue = BundleUtil.localizedString(forKey: "accessibility_voice_message_unplayed")
            }
        default:
            break
        }
        
        guard let duration = durationTimeInterval, duration > 0.0 else {
            return customValue
        }
        
        let formattedDuration = DateFormatter.timeFormatted(Int(duration))
        let durationString = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "accessibility_file_duration"),
            formattedDuration
        )
        
        guard customValue != nil else {
            return durationString
        }
        
        return customValue! + ", " + durationString
    }
    
    public var customAccessibilityHint: String? {
        switch fileMessageType {
        case .image:
            BundleUtil.localizedString(forKey: "accessibility_imageMessage_hint")
        case .video:
            BundleUtil.localizedString(forKey: "accessibility_videoMessage_hint")
        case .sticker:
            nil // No interaction
        case .animatedSticker:
            BundleUtil.localizedString(forKey: "accessibility_animatedStickerMessage_hint")
        case .animatedImage:
            BundleUtil.localizedString(forKey: "accessibility_animatedImageMessage_hint")
        case .file:
            BundleUtil.localizedString(forKey: "accessibility_fileMessage_hint")
        case .voice:
            nil // Handled on cell
        }
    }
    
    public var customAccessibilityTrait: UIAccessibilityTraits {
        switch fileMessageType {
        case .image, .animatedImage, .animatedSticker:
            [.button, .image]
        case .video, .voice:
            [.button, .playsSound, .startsMediaSession]
        case .file:
            [.button, .staticText]
        case .sticker:
            .image
        }
    }
    
    public var accessibilityMessageTypeDescription: String {
        switch fileMessageType {
        case .image:
            BundleUtil.localizedString(forKey: "accessibility_imageMessage_description")
        case .video:
            BundleUtil.localizedString(forKey: "accessibility_videoMessage_description")
        case .sticker, .animatedSticker:
            BundleUtil.localizedString(forKey: "accessibility_stickerMessage_description")
        case .animatedImage:
            BundleUtil.localizedString(forKey: "accessibility_animatedImageMessage_description")
        case .file:
            BundleUtil.localizedString(forKey: "accessibility_fileMessage_description")
        case .voice:
            BundleUtil.localizedString(forKey: "accessibility_voiceMessage_description")
        }
    }
}
