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

extension ImageMessageEntity: ImageMessage {
    
    override public var showRetryAndCancelButton: Bool {
        switch blobDisplayState {
        case .pending, .sendingError, .uploading:
            return true
        default:
            return false
        }
    }
    
    // MARK: - FileMessageProvider
    
    public var fileMessageType: FileMessageType {
        .image(self)
    }
    
    // MARK: - ThumbnailDisplayMessage
    
    public var dataBlobFileSize: Measurement<UnitInformationStorage> {
        if let imageSize = imageSize?.doubleValue {
            return .init(value: imageSize, unit: .bytes)
        }
        else {
            assertionFailure("No image file size available")
            return .init(value: 0, unit: .bytes)
        }
    }
    
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
        if let height = image?.height.intValue,
           let width = image?.width.intValue,
           width > 0, height > 0 {
            return Double(height) / Double(width)
        }
        
        // Show as square otherwise
        return 1
    }
    
    public var caption: String? {
        image?.getCaption()
    }
    
    public func temporaryBlobDataURL() -> URL? {
        guard let imageData = image?.data else {
            return nil
        }
        
        let filename = "v1-imageMessage-\(UUID().uuidString)"
        let url = FileUtility.shared.appTemporaryDirectory.appendingPathComponent(
            "\(filename).\(MEDIA_EXTENSION_IMAGE)"
        )
        
        do {
            try imageData.write(to: url)
        }
        catch {
            DDLogWarn("Writing image blob data to temporary file failed: \(error)")
            return nil
        }
        
        return url
    }
    
    public var assetResourceTypeForAutosave: PHAssetResourceType? {
        .photo
    }
    
    public func createSaveMediaItem(forAutosave: Bool) -> AlbumManager.SaveMediaItem? {
        guard let url = temporaryBlobDataURL() else {
            return nil
        }
        
        return AlbumManager.SaveMediaItem(
            url: url,
            type: .photo,
            filename: readableFileName
        )
    }
}
