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
