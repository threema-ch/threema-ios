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

extension FileMessageEntity: PreviewableMessage {
    public var previewText: String {
        switch fileMessageType {
        case let .voice(voice):
            let formattedDuration = DateFormatter.timeFormatted(Int(voice.durationTimeInterval ?? 0.0))
            return "\(fileMessageType.localizedDescription) (\(formattedDuration))"

        case let .video(message):
            return text(message: message)
            
        case let .image(message):
            return text(message: message)
            
        case let .animatedImage(message):
            return text(message: message)
            
        case let .sticker(message):
            return text(message: message)
            
        case let .animatedSticker(message):
            return text(message: message)
            
        case let .file(message):
            return message.caption ?? message.name
        }
    }
    
    private func text(message: CommonFileMessageMetadata) -> String {
        message.caption ?? fileMessageType.localizedDescription
    }
    
    public var previewSymbolName: String? {
        fileMessageType.symbolName
    }
    
    public var mediaPreview: (thumbnail: UIImage, isPlayable: Bool)? {
        
        guard let thumbnailImage else {
            return nil
        }
        
        switch fileMessageType {
        case .image, .sticker:
            return (thumbnailImage, false)
            
        case .video, .animatedImage, .animatedSticker:
            return (thumbnailImage, true)
            
        case .file, .voice:
            return nil
        }
    }
}
