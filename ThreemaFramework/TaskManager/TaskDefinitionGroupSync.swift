//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

final class TaskDefinitionGroupSync: TaskDefinition, TaskDefinitionTransactionProtocol {

    enum SyncAction: Int, Codable {
        case create, update, delete
    }

    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionGroupSync(
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
        .groupSync
    }

    var syncGroup: Sync_Group
    var syncAction: SyncAction
    var profilePicture: DeltaUpdateType = .unchanged
    var image: Data?

    private enum CodingKeys: String, CodingKey {
        case syncGroup, syncAction, profilePicture, image
    }

    init(syncGroup: Sync_Group, syncAction: SyncAction) {
        self.syncGroup = syncGroup
        self.syncAction = syncAction
        super.init(type: .persistent)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataSyncGroup = try container.decode(Data.self, forKey: .syncGroup)
        self.syncGroup = try Sync_Group(contiguousBytes: dataSyncGroup)
        self.syncAction = try container.decode(SyncAction.self, forKey: .syncAction)
        self.profilePicture = try container.decode(DeltaUpdateType.self, forKey: .profilePicture)
        self.image = try? container.decode(Data.self, forKey: .image)
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let dataSyncGroup = try syncGroup.serializedData()
        try container.encode(dataSyncGroup, forKey: .syncGroup)
        try container.encode(syncAction, forKey: .syncAction)
        try container.encode(profilePicture, forKey: .profilePicture)
        try container.encode(image, forKey: .image)
        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
