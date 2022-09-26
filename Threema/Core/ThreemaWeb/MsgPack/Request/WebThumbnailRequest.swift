//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

class WebThumbnailRequest: WebAbstractMessage {
    
    let id: String
    let messageID: Data
    let type: String
    
    override init(message: WebAbstractMessage) {
        self.id = message.args!["id"] as! String
        let messageIDBase64 = message.args!["messageId"] as! String
        self.messageID = Data(base64Encoded: messageIDBase64, options: .ignoreUnknownCharacters)!
        self.type = message.args!["type"] as! String
        super.init(message: message)
    }
}
