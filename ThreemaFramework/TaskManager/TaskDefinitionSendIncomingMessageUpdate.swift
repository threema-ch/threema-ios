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

import Foundation

class TaskDefinitionSendIncomingMessageUpdate: TaskDefinition {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendIncomingMessageUpdate(
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

    let messageIDs: [Data]
    let messageReadDates: [Date]
    // swiftformat:disable:next all
    let conversationID: D2d_ConversationId

    private enum CodingKeys: String, CodingKey {
        case messageIDs, messageReadDates, conversationID
    }

    // swiftformat:disable:next all
    init(messageIDs: [Data], messageReadDates: [Date], conversationID: D2d_ConversationId) {
        self.messageIDs = messageIDs
        self.messageReadDates = messageReadDates
        self.conversationID = conversationID
        super.init(isPersistent: true)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.messageIDs = try container.decode([Data].self, forKey: .messageIDs)
        self.messageReadDates = try container.decode([Date].self, forKey: .messageReadDates)

        let dataConversationID = try container.decode(Data.self, forKey: .conversationID)
        // swiftformat:disable:next all
        self.conversationID = try D2d_ConversationId(contiguousBytes: dataConversationID)

        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageIDs, forKey: .messageIDs)
        try container.encode(messageReadDates, forKey: .messageReadDates)

        let dataConversationID = try conversationID.serializedData()
        try container.encode(dataConversationID, forKey: .conversationID)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
