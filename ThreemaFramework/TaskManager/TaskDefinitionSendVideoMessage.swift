//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

@objc class TaskDefinitionSendVideoMessage: TaskDefinitionSendBaseMessage {
    override var description: String {
        "<\(type(of: self))>"
    }
    
    @objc var thumbnailBlobID: Data?
    private var thumbnailSizeCurrent: Double?
    @objc var thumbnailSize: NSNumber?

    private enum CodingKeys: String, CodingKey {
        case thumbnailBlobID
        case thumbnailSizeCurrent
    }

    @objc init(
        thumbnailBlobID: Data?,
        thumbnailSize: NSNumber?,
        message: BaseMessage,
        sendContactProfilePicture: Bool
    ) {
        self.thumbnailBlobID = thumbnailBlobID
        if let thumbnailSize = thumbnailSize {
            self.thumbnailSizeCurrent = thumbnailSize.doubleValue
            self.thumbnailSize = thumbnailSize
        }
        super.init(message: message, group: nil, sendContactProfilePicture: sendContactProfilePicture)
    }

    @objc init(
        thumbnailBlobID: Data?,
        thumbnailSize: NSNumber?,
        message: BaseMessage,
        group: Group?,
        sendContactProfilePicture: Bool
    ) {
        self.thumbnailBlobID = thumbnailBlobID
        if let thumbnailSize = thumbnailSize {
            self.thumbnailSizeCurrent = thumbnailSize.doubleValue
            self.thumbnailSize = thumbnailSize
        }
        super.init(message: message, group: group, sendContactProfilePicture: sendContactProfilePicture)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)

        self.thumbnailBlobID = try? container.decode(Data.self, forKey: .thumbnailBlobID)
        self.thumbnailSizeCurrent = try? container.decode(Double.self, forKey: .thumbnailSizeCurrent)
        if let thumbnailSizeCurrent = thumbnailSizeCurrent {
            self.thumbnailSize = NSNumber(value: thumbnailSizeCurrent)
        }
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(thumbnailBlobID, forKey: .thumbnailBlobID)
        try container.encode(thumbnailSizeCurrent, forKey: .thumbnailSizeCurrent)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
