//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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
import ThreemaEssentials

@objc final class TaskDefinitionSendLocationMessage: TaskDefinitionSendBaseMessage {
    override var description: String {
        "<\(Swift.type(of: self))>"
    }
    
    @objc var poiAddress: String?
    
    private enum CodingKeys: String, CodingKey {
        case poiAddress
    }
    
    /// Create send location message task for 1:1 message
    /// - Parameters:
    ///   - poiAddress: String of the address of message to send
    ///   - messageID: ID of message to send
    ///   - receiverIdentity: Receiver identity string for 1:1 conversations
    @objc init(
        poiAddress: String?,
        messageID: Data,
        receiverIdentity: String
    ) {
        self.poiAddress = poiAddress
        super.init(
            messageID: messageID,
            receiverIdentity: receiverIdentity,
            sendContactProfilePicture: true
        )
    }
    
    /// Create send location message task for group message
    /// - Parameters:
    ///   - poiAddress: String of the address of message to send
    ///   - messageID: ID of message to send
    ///   - group: Group the message belongs to
    ///   - groupReceivers: Group members that should receive the message
    init(
        poiAddress: String?,
        messageID: Data,
        group: Group,
        receivers: [ThreemaIdentity]
    ) {
        self.poiAddress = poiAddress
        super.init(
            messageID: messageID,
            group: group,
            receivers: receivers,
            sendContactProfilePicture: true
        )
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)

        self.poiAddress = try? container.decode(String.self, forKey: .poiAddress)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(poiAddress, forKey: .poiAddress)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
