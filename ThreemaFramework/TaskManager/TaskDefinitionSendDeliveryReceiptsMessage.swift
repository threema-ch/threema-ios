//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

@objc class TaskDefinitionSendDeliveryReceiptsMessage: TaskDefinitionSendMessage {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendDeliveryReceiptsMessage(
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

    let fromIdentity: ThreemaIdentity
    let toIdentity: ThreemaIdentity
    let receiptType: UInt8
    let receiptMessageIDs: [Data]
    let receiptReadDates: [Date]

    private enum CodingKeys: String, CodingKey {
        case fromIdentity
        case toIdentity
        case receiptType
        case receiptMessageIDs
        case receiptReadDates
    }

    @objc init(
        fromIdentity: ThreemaIdentity,
        toIdentity: ThreemaIdentity,
        receiptType: UInt8,
        receiptMessageIDs: [Data],
        receiptReadDates: [Date]
    ) {
        self.fromIdentity = fromIdentity
        self.toIdentity = toIdentity
        self.receiptType = receiptType
        self.receiptMessageIDs = receiptMessageIDs
        self.receiptReadDates = receiptReadDates

        super.init(sendContactProfilePicture: false)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fromIdentity = try container.decode(String.self, forKey: .fromIdentity)
        self.toIdentity = try container.decode(String.self, forKey: .toIdentity)
        self.receiptType = try container.decode(UInt8.self, forKey: .receiptType)
        self.receiptMessageIDs = try container.decode([Data].self, forKey: .receiptMessageIDs)
        self.receiptReadDates = try container.decode([Date].self, forKey: .receiptReadDates)

        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fromIdentity, forKey: .fromIdentity)
        try container.encode(toIdentity, forKey: .toIdentity)
        try container.encode(receiptType, forKey: .receiptType)
        try container.encode(receiptMessageIDs, forKey: .receiptMessageIDs)
        try container.encode(receiptReadDates, forKey: .receiptReadDates)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
