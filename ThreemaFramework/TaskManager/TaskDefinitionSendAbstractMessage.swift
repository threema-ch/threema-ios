//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

@objc class TaskDefinitionSendAbstractMessage: TaskDefinition, TaskDefinitionSendMessageProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendAbstractMessage(
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
        "<\(type(of: self)) \(message.loggingDescription)>"
    }
    
    var message: AbstractMessage!
    private var messageData: Data?
    var messageAlreadySentTo = [String]()

    private enum CodingKeys: String, CodingKey {
        case messageData, messageAlreadySentTo
    }

    @objc init(message: AbstractMessage, isPersistent: Bool) {
        super.init(isPersistent: isPersistent)
        self.message = message
    }
    
    @objc convenience init(message: AbstractMessage) {
        self.init(message: message, isPersistent: true)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)

        self.messageData = try container.decode(Data.self, forKey: .messageData)
        if let data = messageData {
            let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
            self.message = try unarchiver.decodeTopLevelObject() as? AbstractMessage
        }
        self.messageAlreadySentTo = try container.decode([String].self, forKey: .messageAlreadySentTo)
    }

    override func encode(to encoder: Encoder) throws {
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.encodeRootObject(message!)
        archiver.finishEncoding()

        messageData = Data(bytes: data.mutableBytes, count: data.count)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageData, forKey: .messageData)
        try container.encode(messageAlreadySentTo, forKey: .messageAlreadySentTo)
        
        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
