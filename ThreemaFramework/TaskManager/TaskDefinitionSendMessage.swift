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
import ThreemaEssentials

/// Task definition base class for sending messages. Group is NULL if is single chat message.
class TaskDefinitionSendMessage: TaskDefinition, TaskDefinitionSendMessageNonceProtocol,
    TaskDefinitionSendMessageProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        preconditionFailure("This function must be overridden")
    }

    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        preconditionFailure("This function must be overridden")
    }
    
    override var description: String {
        "<\(Swift.type(of: self))>"
    }
    
    var isGroupMessage: Bool {
        groupID != nil && groupCreatorIdentity != nil
    }

    // Is nil if is a group message
    var receiverIdentity: String?
    var groupID: Data?
    var groupCreatorIdentity: String?
    var groupName: String?
    var receivingGroupMembers: Set<String>?
    var isNoteGroup: Bool?
    var sendContactProfilePicture: Bool?
    
    var nonces = TaskReceiverNonce()

    private(set) var messageAlreadySentToQueue =
        DispatchQueue(label: "ch.threema.TaskDefinitionSendMessage.messageAlreadySentToQueue")
    var messageAlreadySentTo = TaskReceiverNonce()

    private enum CodingKeys: String, CodingKey {
        case receiverIdentity
        case groupID
        case groupCreatorIdentity
        case groupName
        case allGroupMembers
        case isNoteGroup
        case sendContactProfilePicture
        case messageAlreadySentTo
    }

    init(sendContactProfilePicture: Bool) {
        super.init(type: .persistent)
        self.sendContactProfilePicture = sendContactProfilePicture
    }
    
    init(group: Group, groupReceivers: [ThreemaIdentity]?, sendContactProfilePicture: Bool) {
        super.init(type: .persistent)
        self.groupID = group.groupID
        self.groupCreatorIdentity = group.groupCreatorIdentity
        self.groupName = group.name
        if let groupReceivers {
            self.receivingGroupMembers = Set(groupReceivers.map(\.string))
        }
        else {
            self.receivingGroupMembers = Set(group.members.map(\.identity.string))
        }
        self.isNoteGroup = group.isNoteGroup
        self.sendContactProfilePicture = sendContactProfilePicture
        
        assert(receiverIdentity == nil)
    }

    init(receiverIdentity: String?, group: Group?, sendContactProfilePicture: Bool) {
        super.init(type: .persistent)
        self.receiverIdentity = receiverIdentity
        self.groupID = group?.groupID
        self.groupCreatorIdentity = group?.groupCreatorIdentity
        self.groupName = group?.name
        if let groupMembers = group?.members {
            self.receivingGroupMembers = Set(groupMembers.map(\.identity.string))
        }
        self.isNoteGroup = group?.isNoteGroup
        self.sendContactProfilePicture = sendContactProfilePicture
    }

    init(
        receiverIdentity: String?,
        groupID: Data?,
        groupCreatorIdentity: String?,
        groupName: String?,
        allGroupMembers: Set<String>?,
        isNoteGroup: Bool?,
        sendContactProfilePicture: Bool
    ) {
        super.init(type: .persistent)
        self.receiverIdentity = receiverIdentity
        self.groupID = groupID
        self.groupCreatorIdentity = groupCreatorIdentity
        self.groupName = groupName
        self.receivingGroupMembers = allGroupMembers
        self.isNoteGroup = isNoteGroup
        self.sendContactProfilePicture = sendContactProfilePicture
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)

        self.receiverIdentity = try container.decode(String?.self, forKey: .receiverIdentity)
        self.groupID = try container.decode(Data?.self, forKey: .groupID)
        self.groupCreatorIdentity = try container.decode(String?.self, forKey: .groupCreatorIdentity)
        self.groupName = try container.decode(String?.self, forKey: .groupName)
        self.receivingGroupMembers = try container.decode(Set<String>?.self, forKey: .allGroupMembers)
        self.isNoteGroup = try container.decode(Bool?.self, forKey: .isNoteGroup)
        self.sendContactProfilePicture = try container.decode(Bool?.self, forKey: .sendContactProfilePicture)
        messageAlreadySentToQueue.sync {
            do {
                self.messageAlreadySentTo = try container.decode(TaskReceiverNonce.self, forKey: .messageAlreadySentTo)
            }
            catch {
                self.messageAlreadySentTo = TaskReceiverNonce()
            }
        }
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(receiverIdentity, forKey: .receiverIdentity)
        try container.encode(groupID, forKey: .groupID)
        try container.encode(groupCreatorIdentity, forKey: .groupCreatorIdentity)
        try container.encode(groupName, forKey: .groupName)
        try container.encode(receivingGroupMembers, forKey: .allGroupMembers)
        try container.encode(isNoteGroup, forKey: .isNoteGroup)
        try container.encode(sendContactProfilePicture, forKey: .sendContactProfilePicture)
        messageAlreadySentToQueue.sync {
            do {
                try container.encode(messageAlreadySentTo, forKey: .messageAlreadySentTo)
            }
            catch {
                // no-op
            }
        }

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
