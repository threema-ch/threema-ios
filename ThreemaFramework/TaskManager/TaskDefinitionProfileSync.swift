//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

final class TaskDefinitionProfileSync: TaskDefinition, TaskDefinitionTransactionProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionProfileSync(
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
                logSendMessageToChat: .none,
                logReceiveMessageAckFromChat: .none
            )
        )
    }

    override var description: String {
        "<\(Swift.type(of: self))>"
    }

    var scope: D2d_TransactionScope.Scope {
        .userProfileSync
    }

    var syncUserProfile: Sync_UserProfile
    var profileImage: Data?
    var linkMobileNoPending: Bool
    var linkEmailPending: Bool

    init(
        syncUserProfile: Sync_UserProfile,
        profileImage: Data?,
        linkMobileNoPending: Bool,
        linkEmailPending: Bool
    ) {
        self.syncUserProfile = syncUserProfile
        self.profileImage = profileImage
        self.linkMobileNoPending = linkMobileNoPending
        self.linkEmailPending = linkEmailPending

        super.init(type: .volatile)
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
