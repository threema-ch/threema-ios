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
import ThreemaProtocols

final class TaskDefinitionSendDeliveryReceiptsMessage: TaskDefinitionSendMessage {
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

    let fromIdentity: String
    let toIdentity: String
    let receiptType: ReceiptType
    private let receiptTypeValue: UInt8
    let receiptMessageIDs: [Data]
    let receiptReadDates: [Date]
    let excludeFromSending: [Data]

    private enum CodingKeys: String, CodingKey {
        case fromIdentity
        case toIdentity
        case receiptType
        case receiptMessageIDs
        case receiptReadDates
        case excludeFromSending
    }

    private enum CodingError: Error {
        case unknownReceiptType
    }

    @objc init(
        fromIdentity: String,
        toIdentity: String,
        receiptType: ReceiptType,
        receiptMessageIDs: [Data],
        receiptReadDates: [Date],
        excludeFromSending: [Data]
    ) {
        self.fromIdentity = fromIdentity
        self.toIdentity = toIdentity
        self.receiptType = receiptType
        self.receiptTypeValue = receiptType.rawValue
        self.receiptMessageIDs = receiptMessageIDs
        self.receiptReadDates = receiptReadDates
        self.excludeFromSending = excludeFromSending

        super.init(sendContactProfilePicture: false)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fromIdentity = try container.decode(String.self, forKey: .fromIdentity)
        self.toIdentity = try container.decode(String.self, forKey: .toIdentity)
        self.receiptTypeValue = try container.decode(UInt8.self, forKey: .receiptType)
        self.receiptType = try TaskDefinitionSendDeliveryReceiptsMessage.receiptType(rawValue: receiptTypeValue)
        self.receiptMessageIDs = try container.decode([Data].self, forKey: .receiptMessageIDs)
        self.receiptReadDates = try container.decode([Date].self, forKey: .receiptReadDates)
        self.excludeFromSending = try container.decode([Data].self, forKey: .excludeFromSending)

        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fromIdentity, forKey: .fromIdentity)
        try container.encode(toIdentity, forKey: .toIdentity)
        try container.encode(receiptTypeValue, forKey: .receiptType)
        try container.encode(receiptMessageIDs, forKey: .receiptMessageIDs)
        try container.encode(receiptReadDates, forKey: .receiptReadDates)
        try container.encode(excludeFromSending, forKey: .excludeFromSending)

        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }

    private class func receiptType(rawValue: UInt8) throws -> ReceiptType {
        guard let type = ReceiptType(rawValue: rawValue) else {
            throw CodingError.unknownReceiptType
        }
        return type
    }
}
