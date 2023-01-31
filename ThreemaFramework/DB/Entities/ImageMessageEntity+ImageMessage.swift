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

extension ImageMessageEntity: ImageMessage {
    
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
           width != 0 {
            return Double(height) / Double(width)
        }
        
        // Take the metadata if no thumbnail data is available
        if let height = image?.height.intValue,
           let width = image?.width.intValue,
           width != 0 {
            return Double(height) / Double(width)
        }
        
        // Show as square otherwise
        return 1
    }
    
    public var caption: String? {
        image?.getCaption()
    }
}
