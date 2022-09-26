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

// MARK: - FileMessageEntity + FileMessageProvider

extension FileMessageEntity: FileMessageProvider {
    public var fileMessageType: FileMessageType {
        switch renderType {
        case .imageMessage:
            return .image(self)
        case .stickerMessage:
            return .sticker(self)
        case .animatedImageMessage:
            return .placeholder(self)
        case .animatedStickerMessage:
            return .placeholder(self)
        case .videoMessage:
            return .placeholder(self)
        case .audioMessage:
            return .placeholder(self)
        case .fileMessage:
            return .file(self)
        }
    }
}

// MARK: - FileMessageEntity + CommonFileMessageMetadata

extension FileMessageEntity: CommonFileMessageMetadata {
    public var dataBlobFileSize: Measurement<UnitInformationStorage> {
        if let fileSize = fileSize?.doubleValue {
            return .init(value: fileSize, unit: .bytes)
        }
        else {
            assertionFailure("No file size available")
            return .init(value: 0, unit: .bytes)
        }
    }
}

// MARK: - FileMessageEntity + ImageMessage, StickerMessage

extension FileMessageEntity: ImageMessage, StickerMessage {
    public var thumbnailImage: UIImage? {
        thumbnail?.uiImage
    }
    
    public var heightToWidthAspectRatio: Double {
        // Take the thumbnail if it exists as this is what we show
        if let height = thumbnail?.height.intValue,
           let width = thumbnail?.width.intValue,
           width != 0 {
            return Double(height) / Double(width)
        }
        
        // Take the metadata if no thumbnail data is available
        if let height = height?.intValue,
           let width = width?.intValue,
           width != 0 {
            return Double(height) / Double(width)
        }
        
        // Show as square otherwise
        return 1
    }
}

// MARK: - FileMessageEntity + FileMessage

extension FileMessageEntity: FileMessage {
    public var name: String {
        fileName ?? ""
    }
    
    public var `extension`: String {
        let nameExtension = URL(fileURLWithPath: name).pathExtension
        if !nameExtension.isEmpty {
            return nameExtension
        }
        
        // Fallback if the extension extraction didn't work
        if let preferredExtension = UTIConverter.preferredFileExtension(forMimeType: mimeType) {
            return preferredExtension
        }
        
        return ""
    }
}
