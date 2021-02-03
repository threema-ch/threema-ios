//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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
import CocoaLumberjackSwift

@objc public class URLSender : NSObject {
    
    /// Sends the file from url as a file message
    /// - Parameters:
    ///   - url: A local url pointing to a file
    ///   - asFile: Whether the file should be sent as is. Can be true if the photo/video has previously been converted
    ///   or if the user has explicitly chosen to send this file to be rendered as a file
    ///   - caption: The caption displayed below the file
    ///   - conversation: The conversation to which the file should be sent
    @objc public static func sendUrl(_ url : URL, asFile : Bool, caption : String?, conversation : Conversation) {
        let senderItem : URLSenderItem?
        if asFile {
            let mimeType = UTIConverter.mimeType(fromUTI: UTIConverter.uti(forFileURL: url))
            senderItem = URLSenderItem.init(url: url, type: mimeType, renderType: 0, sendAsFile: true)
        } else {
            senderItem = URLSenderItemCreator.getSenderItem(for: url)
        }
        if caption != nil {
            senderItem?.caption = caption
        }
        
        if senderItem == nil {
            DDLogError("Could not create sender item")
            return
        }
        
        let sender = FileMessageSender()
        sender.send(senderItem, in: conversation)
    }
}
