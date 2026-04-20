import Foundation

final class TaskDefinitionGroupDissolve: TaskDefinitionSendMessage {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionGroupDissolve(
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

    var toMembers = [String]()

    private enum CodingKeys: String, CodingKey {
        case toMembers
    }

    required init(group: Group) {
        super.init(receiverIdentity: nil, group: group, sendContactProfilePicture: false)
        self.type = .persistent
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)

        self.toMembers = try container.decode([String].self, forKey: .toMembers)
        self.type = .persistent
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toMembers, forKey: .toMembers)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
