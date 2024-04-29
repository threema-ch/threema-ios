//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import ThreemaEssentials

// TODO: (IOS-4567) Remove workaround

/// **Workaround**: Task definition to run Threema Protocols _FS Refresh Steps_
///
/// This is an optimization (& workaround) to reduce task creation explosion and should only be created from within
/// `ForwardSecurityRefreshSteps`. This should be removed when IOS-4567 is completed.
class TaskDefinitionRunForwardSecurityRefreshSteps: TaskDefinition, TaskDefinitionSendMessageNonceProtocol,
    TaskDefinitionSendMessageProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionRunForwardSecurityRefreshSteps(
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
    
    /// All identities the _FS Refresh Steps_ should be executed for
    let contactIdentities: [ThreemaIdentity]

    var nonces = TaskReceiverNonce()
    
    private(set) var messageAlreadySentToQueue =
        DispatchQueue(label: "ch.threema.TaskDefinitionSendMessage.messageAlreadySentToQueue")
    var messageAlreadySentTo = TaskReceiverNonce()

    private enum CodingKeys: String, CodingKey {
        case contactIdentities
        case messageAlreadySentTo
    }
    
    /// Create a new task to run _FS Refresh Steps_
    /// - Parameter contactIdentities: All identities the _FS Refresh Steps_ should be executed for
    init(with contactIdentities: [ThreemaIdentity]) {
        self.contactIdentities = contactIdentities
        super.init(isPersistent: true)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.contactIdentities = try container.decode([ThreemaIdentity].self, forKey: .contactIdentities)
        
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
        
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
        try container.encode(contactIdentities, forKey: .contactIdentities)
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
