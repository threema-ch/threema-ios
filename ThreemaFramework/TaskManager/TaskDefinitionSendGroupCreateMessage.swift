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

final class TaskDefinitionSendGroupCreateMessage: TaskDefinitionSendMessage {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendGroupCreateMessage(
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
    
    /// Receiver of group create message
    ///
    /// This should not include any inactive members of the group
    let toMembers: [String]

    /// Removed group members (these will always get a message)
    let removedMembers: [String]?
    
    /// All group members
    let members: Set<String>
    
    private enum CodingKeys: String, CodingKey {
        case members
        case removedMembers
        case toMembers
    }
    
    /// Create a new group create/setup task
    ///
    /// - Parameters:
    ///   - group: Group the setup message is sent to
    ///   - toMembers: Member that should get the create message (this should no include inactive members)
    ///   - removedMembers: Members that are removed with this group create message
    ///   - members: All current members of the group (this should not include any `removedMembers`)
    ///   - sendContactProfilePicture: Should a contact profile picture be sent?
    convenience init(
        group: Group,
        to toMembers: [String],
        removed removedMembers: [String]? = nil,
        members: Set<String>,
        sendContactProfilePicture: Bool = false
    ) {
        self.init(
            groupID: group.groupID,
            groupCreatorIdentity: group.groupCreatorIdentity,
            groupName: group.name,
            allGroupMembers: group.allMemberIdentities,
            isNoteGroup: group.isNoteGroup,
            to: toMembers,
            removed: removedMembers,
            members: members,
            sendContactProfilePicture: sendContactProfilePicture
        )
    }

    init(
        groupID: Data,
        groupCreatorIdentity: String,
        groupName: String?,
        allGroupMembers: Set<String>?,
        isNoteGroup: Bool?,
        to toMembers: [String],
        removed removedMembers: [String]? = nil,
        members: Set<String>,
        sendContactProfilePicture: Bool = false
    ) {
        self.toMembers = toMembers
        self.removedMembers = removedMembers
        self.members = members

        super.init(
            receiverIdentity: nil,
            groupID: groupID,
            groupCreatorIdentity: groupCreatorIdentity,
            groupName: groupName,
            allGroupMembers: allGroupMembers,
            isNoteGroup: isNoteGroup,
            sendContactProfilePicture: sendContactProfilePicture
        )
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.toMembers = try container.decode([String].self, forKey: .toMembers)
        self.removedMembers = try? container.decode([String].self, forKey: .removedMembers)
        self.members = try container.decode(Set<String>.self, forKey: .members)
        
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toMembers, forKey: .toMembers)
        try container.encode(removedMembers, forKey: .removedMembers)
        try container.encode(members, forKey: .members)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
