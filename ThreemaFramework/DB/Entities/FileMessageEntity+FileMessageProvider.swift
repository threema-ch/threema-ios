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

import CocoaLumberjackSwift
import Foundation
import Photos

// MARK: - FileMessageEntity + FileMessageProvider

extension FileMessageEntity: FileMessageProvider {
    public var fileMessageType: FileMessageType {
        switch renderType {
        case .imageMessage:
            return .image(self)
        case .stickerMessage:
            return .sticker(self)
        case .animatedImageMessage:
            return .animatedImage(self)
        case .animatedStickerMessage:
            return .animatedSticker(self)
        case .videoMessage:
            return .video(self)
        case .voiceMessage:
            return .voice(self)
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
           width > 0, height > 0 {
            return Double(height) / Double(width)
        }
        
        // Take the metadata if no thumbnail data is available
        if let height = height?.intValue,
           let width = width?.intValue,
           width > 0, height > 0 {
            return Double(height) / Double(width)
        }
        
        // Show as square otherwise
        return 1
    }
}

// MARK: - FileMessageEntity + VideoMessage, VoiceMessage

extension FileMessageEntity: VideoMessage, VoiceMessage {
   
    // Info: This will always return 0 on simulators, last tested Xcode 14.1
    public var durationTimeInterval: TimeInterval? {
        guard let duration = duration else {
            return nil
        }
        
        return duration.doubleValue
    }

    public func temporaryBlobDataURL() -> URL? {
        guard let data = data?.data else {
            return nil
        }

        guard var mimeType = mimeType else {
            return nil
        }
        
        // Since the AVAudioPlayer can not handle aac files, we save them as mp4.
        if mimeType == "audio/aac" {
            mimeType = "audio/mp4"
        }
        
        guard let ext = UTIConverter.preferredFileExtension(forMimeType: mimeType) else {
            return nil
        }
        
        let filename = "v1-fileMessage-\(UUID().uuidString)"
        guard let url = FileUtility.appTemporaryDirectory?.appendingPathComponent("\(filename).\(ext)") else {
            return nil
        }
        
        do {
            try data.write(to: url)
        }
        catch {
            DDLogWarn("Writing blob data to temporary file failed: \(error)")
            return nil
        }
        
        return url
    }
}

// MARK: - FileMessageEntity + ThumbnailDisplayMessage

extension FileMessageEntity: ThumbnailDisplayMessage {
    
    private var assetResourceType: PHAssetResourceType? {
        switch fileMessageType {
        case .image, .animatedImage, .sticker, .animatedSticker:
            return .photo
        case .video:
            return .video
        case .voice, .file:
            return nil
        }
    }
    
    private var assetResourceTypeForAutosave: PHAssetResourceType? {
        switch fileMessageType {
        case .image, .animatedImage:
            return .photo
        case .video:
            return .video
        case .voice, .file, .sticker, .animatedSticker:
            return nil
        }
    }
    
    public func createSaveMediaItem(forAutosave: Bool) -> AlbumManager.SaveMediaItem? {
       
        let type = forAutosave ? assetResourceTypeForAutosave : assetResourceType
        
        guard let url = temporaryBlobDataURL(),
              let type else {
            DDLogNotice(
                "[ThumbnailDisplayMessage] SaveMediaItem creation failed, or type is not supported for auto-saving."
            )
            return nil
        }
        return AlbumManager.SaveMediaItem(
            url: url,
            type: type,
            filename: readableFileName
        )
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
