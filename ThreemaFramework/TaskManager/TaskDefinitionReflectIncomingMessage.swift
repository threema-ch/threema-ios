import Foundation

final class TaskDefinitionReflectIncomingMessage: TaskDefinition, TaskDefinitionSendMessageNonceProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionReflectIncomingMessage(
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
        "<\(Swift.type(of: self)) \(message.loggingDescription)>"
    }

    let message: AbstractMessage
    var nonces = TaskReceiverNonce()

    private enum CodingKeys: String, CodingKey {
        case message, messageData
    }

    private enum CodingError: Error {
        case messageDataMissing
    }

    @objc init(message: AbstractMessage) {
        self.message = message
        super.init(type: .dropOnDisconnect)
        self.retry = false
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let messageData = try container.decode(Data.self, forKey: .messageData)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: messageData)
        guard let decodedMessage = try unarchiver.decodeTopLevelObject(
            of: AbstractMessage.self,
            forKey: CodingKeys.message.rawValue
        ) else {
            throw CodingError.messageDataMissing
        }
        self.message = decodedMessage

        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }

    override func encode(to encoder: Encoder) throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        archiver.encode(message, forKey: CodingKeys.message.rawValue)
        archiver.finishEncoding()

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(archiver.encodedData, forKey: .messageData)

        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }
}
