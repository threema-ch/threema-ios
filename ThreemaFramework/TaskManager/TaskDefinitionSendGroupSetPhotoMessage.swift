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

final class TaskDefinitionSendGroupSetPhotoMessage: TaskDefinitionSendMessage {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendGroupSetPhotoMessage(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
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
    let size: UInt32
    let blobID: Data
    let encryptionKey: Data
    
    private enum CodingKeys: String, CodingKey {
        case fromMember
        case toMembers
        case size
        case blobID
        case encryptionKey
    }
    
    init(
        group: Group,
        from: String,
        to: [String],
        size: UInt32,
        blobID: Data,
        encryptionKey: Data,
        sendContactProfilePicture: Bool = false
    ) {
        self.fromMember = from
        self.toMembers = to
        self.size = size
        self.blobID = blobID
        self.encryptionKey = encryptionKey
        
        super.init(receiverIdentity: nil, group: group, sendContactProfilePicture: sendContactProfilePicture)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fromMember = try container.decode(String.self, forKey: .fromMember)
        self.toMembers = try container.decode([String].self, forKey: .toMembers)
        self.size = try container.decode(UInt32.self, forKey: .size)
        self.blobID = try container.decode(Data.self, forKey: .blobID)
        self.encryptionKey = try container.decode(Data.self, forKey: .encryptionKey)
        
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fromMember, forKey: .fromMember)
        try container.encode(toMembers, forKey: .toMembers)
        try container.encode(size, forKey: .size)
        try container.encode(blobID, forKey: .blobID)
        try container.encode(encryptionKey, forKey: .encryptionKey)
        
        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
