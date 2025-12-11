//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaMacros

extension ImageMessageEntity {
    override public func additionalExportInfo() -> String? {
        var info = "\(#localize("image")) (\(blobExportFilename ?? ""))"
        if let caption = image?.caption() {
            info = info + ", \(#localize("caption")): \(caption)"
        }
        return info
    }
    
    override public func contentToCheckForMentions() -> String? {
        image?.caption()
    }
    
    #if !DEBUG
        override public var debugDescription: String {
            "<\(type(of: self))>:\(AudioDataEntity.self), image = \(image?.description ?? "nil"),  thumbnail = \(thumbnail?.description ?? "nil"), imageBlobId = \("***"), imageNonce = \("***"), imageSize = \(imageSize?.description ?? "nil"), progress = \(progress?.description ?? "nil"), encryptionKey = \("***")"
        }
    #endif
}
