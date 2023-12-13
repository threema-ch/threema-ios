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

import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials

/// Implementation of "Common Group Receive Steps" according to the protocol specification
///
/// All inline comments are directly from the protocol
struct CommonGroupReceiveSteps {
        
    /// Result of running the "Common Group Receive Step"
    enum Result {
        case discardMessage
        case keepMessage
    }
    
    private let myIdentityStore: MyIdentityStoreProtocol
    private let groupManager: GroupManagerProtocol
    
    init(businessInjector: FrameworkInjectorProtocol = BusinessInjector()) {
        self.myIdentityStore = businessInjector.myIdentityStore
        self.groupManager = businessInjector.groupManager
    }
    
    func run(for groupIdentity: GroupIdentity, sender: ThreemaIdentity) -> Result {
        
        // 1. Look up the group.
        guard let group = groupManager.group(for: groupIdentity) else {
            // 2. If the group could not be found:
            //     1. If the user is the creator of the group (as alleged by the message),
            //        discard the message and abort these steps.
            //     2. Send a [`group-sync-request`](ref:e2e.group-sync-request) to the
            //        group creator, discard the message and abort these steps.
            
            if groupIdentity.creator.string != myIdentityStore.identity {
                groupManager.sendSyncRequest(for: groupIdentity)
            }
            
            return .discardMessage
        }
        
        guard group.isSelfMember else {
            // 3. If the group is marked as _left_:
            //     1. If the user is the creator of the group, send a
            //        [`group-setup`](ref:e2e.group-setup) with an empty members list back
            //        to the sender, discard the message and abort these steps.
            //     2. Send a [`group-leave`](ref:e2e.group-leave) back to the sender,
            //        discard the message and abort these steps.

            if group.isSelfCreator {
                groupManager.dissolve(groupID: groupIdentity.id, to: Set([sender.string]))
            }
            else {
                groupManager.leave(groupWith: groupIdentity, inform: .members([sender]))
            }
            
            return .discardMessage
        }
        
        guard group.isMember(identity: sender.string) else {
            // 4. If the sender is not a member of the group:
            //    1. If the user is the creator of the group, send a
            //       [`group-setup`](ref:e2e.group-setup) with an empty members list back
            //       to the sender.
            //    2. Discard the message and abort these steps.
            
            if group.isSelfCreator {
                groupManager.dissolve(groupID: groupIdentity.id, to: Set([sender.string]))
            }
            
            return .discardMessage
        }
        
        return .keepMessage
    }
}
