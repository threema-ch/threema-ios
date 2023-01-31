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

class TaskDefinitionSendGroupDeliveryReceiptsMessage: TaskDefinitionSendMessage {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendGroupDeliveryReceiptsMessage(
            taskContext: taskContext,
            taskDefinition: self,
            frameworkInjector: frameworkInjector
        )
    }

    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        create(
            frameworkInjector: frameworkInjector,
            taskContext: TaskContext(
                logReflectMessageToMediator: .reflectOutgoingMessageToMediator,
                logReceiveMessageAckFromMediator: .receiveOutgoingMessageAckFromMediator,
                logSendMessageToChat: .sendOutgoingMessageToChat,
                logReceiveMessageAckFromChat: .receiveOutgoingMessageAckFromChat
            )
        )
    }
    
    override var description: String {
        "<\(type(of: self))>"
    }

    let fromMember: String
    let toMembers: [String]
    @objc let receiptType: UInt8
    @objc let receiptMessageIDs: [Data]

    private enum CodingKeys: String, CodingKey {
        case fromMember
        case toMembers
        case receiptType
        case receiptMessageIDs
    }
    
    @objc init(
        group: Group?,
        from: String,
        to: [String],
        receiptType: UInt8,
        receiptMessageIDs: [Data],
        sendContactProfilePicture: Bool
    ) {
        self.fromMember = from
        self.toMembers = to
        self.receiptType = receiptType
        self.receiptMessageIDs = receiptMessageIDs
        
        super.init(group: group, sendContactProfilePicture: sendContactProfilePicture)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fromMember = try container.decode(String.self, forKey: .fromMember)
        self.toMembers = try container.decode([String].self, forKey: .toMembers)
        self.receiptType = try container.decode(UInt8.self, forKey: .receiptType)
        self.receiptMessageIDs = try container.decode([Data].self, forKey: .receiptMessageIDs)
        
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fromMember, forKey: .fromMember)
        try container.encode(toMembers, forKey: .toMembers)
        try container.encode(receiptType, forKey: .receiptType)
        try container.encode(receiptMessageIDs, forKey: .receiptMessageIDs)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
