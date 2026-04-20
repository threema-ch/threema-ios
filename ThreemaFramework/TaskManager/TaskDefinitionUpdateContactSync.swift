import Foundation
import ThreemaProtocols

/// Reflect update of contacts to mediator server.
final class TaskDefinitionUpdateContactSync: TaskDefinition, TaskDefinitionTransactionProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionUpdateContactSync(
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
        .contactSync
    }

    var deltaSyncContacts: [DeltaSyncContact]
    
    private enum CodingKeys: String, CodingKey {
        case deltaSyncContacts
    }
    
    init(deltaSyncContacts: [DeltaSyncContact]) {
        self.deltaSyncContacts = deltaSyncContacts
        super.init(type: .persistent)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deltaSyncContacts = try container.decode([DeltaSyncContact].self, forKey: .deltaSyncContacts)
    
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(deltaSyncContacts, forKey: .deltaSyncContacts)
        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
