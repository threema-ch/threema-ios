import Foundation
import ThreemaProtocols

final class TaskDefinitionSendGroupCallStartMessage: TaskDefinitionSendMessage {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendGroupCallStartMessage(
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

    let fromMember: String
    let toMembers: [String]
    let groupCallStartMessage: CspE2e_GroupCallStart

    private enum CodingKeys: String, CodingKey {
        case fromMember
        case toMembers
        case groupCallStartMessage
    }
    
    init(
        group: Group,
        from: String,
        to: [String],
        groupCallStartMessage: CspE2e_GroupCallStart,
        sendContactProfilePicture: Bool
    ) {
        self.fromMember = from
        self.toMembers = to
        self.groupCallStartMessage = groupCallStartMessage
        
        super.init(receiverIdentity: nil, group: group, sendContactProfilePicture: sendContactProfilePicture)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fromMember = try container.decode(String.self, forKey: .fromMember)
        self.toMembers = try container.decode([String].self, forKey: .toMembers)
        self
            .groupCallStartMessage = try CspE2e_GroupCallStart(
                serializedData: container
                    .decode(Data.self, forKey: .groupCallStartMessage)
            )
        
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fromMember, forKey: .fromMember)
        try container.encode(toMembers, forKey: .toMembers)
        try container.encode(groupCallStartMessage.serializedData(), forKey: .groupCallStartMessage)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
