//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaProtocols

final class TaskDefinitionSendReactionMessage: TaskDefinitionSendMessage {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendReactionMessage(
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
        "<\(Swift.type(of: self))>"
    }
    
    let reaction: CspE2e_Reaction
    
    private enum CodingKeys: String, CodingKey {
        case fromIdentity
        case toIdentity
        case reaction
    }
    
    /// Create send reaction message task for 1:1 chat
    /// - Parameters:
    ///   - reaction: String of the reaction to send
    ///   - receiverIdentity: Receiver identity string for 1:1 conversations
    init(
        reaction: CspE2e_Reaction,
        receiverIdentity: String
    ) {
        self.reaction = reaction
        super.init(receiverIdentity: receiverIdentity, group: nil, sendContactProfilePicture: true)
    }
    
    /// Create send reaction message task for a group
    /// - Parameters:
    ///   - reaction: CspE2e_Reaction of the reaction to send
    ///   - group: Group the message belongs to
    init(
        reaction: CspE2e_Reaction,
        group: Group
    ) {
        self.reaction = reaction
        super.init(receiverIdentity: nil, group: group, sendContactProfilePicture: true)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.reaction = try CspE2e_Reaction(
            serializedData: container
                .decode(Data.self, forKey: .reaction)
        )
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(reaction.serializedData(), forKey: .reaction)
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }
}