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

import CocoaLumberjackSwift
import Foundation

extension VideoMessageEntity: VideoMessage {
        
    // MARK: - FileMessageProvider
    
    public var fileMessageType: FileMessageType {
        .video(self)
    }
    
    // MARK: - ThumbnailDisplayMessage
    
    public var dataBlobFileSize: Measurement<UnitInformationStorage> {
        if let videoSize = videoSize?.doubleValue {
            return .init(value: videoSize, unit: .bytes)
        }
        else {
            assertionFailure("No video file size available")
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
           width != 0 {
            return Double(height) / Double(width)
        }
        
        // Show as square otherwise
        return 1
    }
    
    public var caption: String? {
        // Legacy videos did not support captions
        nil
    }
    
    public var durationTimeInterval: TimeInterval? {
        guard let duration = duration else {
            return nil
        }
        
        return duration.doubleValue
    }
    
    public var temporaryBlobDataURL: URL? {
        guard let videoData = video?.data else {
            return nil
        }
        
        let filename = "v1-videoMessage-\(objectID.hashValue)".hashValue
        guard let url = FileUtility.appTemporaryDirectory?.appendingPathComponent(
            "\(filename).\(MEDIA_EXTENSION_VIDEO)"
        ) else {
            return nil
        }
        
        if !FileUtility.isExists(fileURL: url) {
            do {
                try videoData.write(to: url)
            }
            catch {
                DDLogWarn("Writing video blob data to temporary file failed: \(error)")
                return nil
            }
        }
        
        return url
    }
}
