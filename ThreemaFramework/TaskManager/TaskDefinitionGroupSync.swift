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
