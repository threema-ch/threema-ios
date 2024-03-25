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

final class TaskDefinitionSendGroupRenameMessage: TaskDefinitionSendMessage {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendGroupRenameMessage(
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
    
    /// Sender of this message
    let fromMember: String
    
    /// Receivers of this message
    let toMembers: [String]
    
    /// Group name to send
    let name: String?

    private enum CodingKeys: String, CodingKey {
        case fromMember
        case toMembers
        case name
    }
    
    init(
        group: Group,
        from: String,
        to: [String],
        newName: String?,
        sendContactProfilePicture: Bool = false
    ) {
        self.fromMember = from
        self.toMembers = to
        self.name = newName
        
        super.init(receiverIdentity: nil, group: group, sendContactProfilePicture: sendContactProfilePicture)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fromMember = try container.decode(String.self, forKey: .fromMember)
        self.toMembers = try container.decode([String].self, forKey: .toMembers)
        self.name = try? container.decode(String.self, forKey: .name)
        
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fromMember, forKey: .fromMember)
        try container.encode(toMembers, forKey: .toMembers)
        try container.encode(name, forKey: .name)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
