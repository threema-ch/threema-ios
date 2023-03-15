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

public extension FileMessageEntity {
    
    /// Possible render types of a file message entity
    enum RenderType {
        /// An image represented though its thumbnail
        case imageMessage
        /// Like an image but no background
        case stickerMessage
        /// Like an image but animated
        case animatedImageMessage
        /// Like an image but animated and no background
        case animatedStickerMessage
        /// A video represented by a playable thumbnail
        case videoMessage
        /// An voice message that can be played inline
        case voiceMessage
        /// A file that can be opened
        case fileMessage
    }
    
    /// How should this message be rendered?
    /// When changing this you should also change `(NSArray *)filesMessagesFilteredForPhotoBrowserForConversation:(Conversation *)conversation` in `EntityFetcher`
    var renderType: RenderType {
        if UTIConverter.isImageMimeType(mimeType), UTIConverter.isRenderingImageMimeType(mimeType) {
            if type?.intValue == 1 {
                return .imageMessage
            }
            else if type?.intValue == 2 {
                return .stickerMessage
            }
            
            return .fileMessage
        }
        else if UTIConverter.isGifMimeType(mimeType) {
            if type?.intValue == 1 {
                return .animatedImageMessage
            }
            else if type?.intValue == 2 {
                return .animatedStickerMessage
            }
            
            return .fileMessage
        }
        else if UTIConverter.isRenderingVideoMimeType(mimeType) {
            if type?.intValue == 1 || type?.intValue == 2 {
                return .videoMessage
            }
            
            return .fileMessage
        }
        else if UTIConverter.isRenderingAudioMimeType(mimeType) {
            if type?.intValue == 1 || type?.intValue == 2 {
                return .voiceMessage
            }
            
            return .fileMessage
        }
        
        return .fileMessage
    }
    
    override var showRetryAndCancelButton: Bool {
        switch blobDisplayState {
        case .pending, .sendingError, .uploading:
            return true
        default:
            return false
        }
    }
}
