import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
import ThreemaProtocols

@objc final class TaskDefinitionSendDeleteEditMessage: TaskDefinitionSendMessage {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendDeleteEditMessage(
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
        "<\(Swift.type(of: self)) \(deleteMessage?.loggingDescription ?? editMessage?.loggingDescription ?? "-")>"
    }

    let deleteMessage: CspE2e_DeleteMessage?
    let editMessage: CspE2e_EditMessage?

    private enum CodingKeys: String, CodingKey {
        case deleteMessage, editMessage
    }

    private enum CodingError: Error {
        case messageDataMissing
    }

    init(receiverIdentity: ThreemaIdentity?, group: Group?, deleteMessage: CspE2e_DeleteMessage) {
        self.deleteMessage = deleteMessage
        self.editMessage = nil
        super.init(receiverIdentity: receiverIdentity?.rawValue, group: group, sendContactProfilePicture: false)
    }

    init(receiverIdentity: ThreemaIdentity?, group: Group?, editMessage: CspE2e_EditMessage) {
        self.deleteMessage = nil
        self.editMessage = editMessage
        super.init(receiverIdentity: receiverIdentity?.rawValue, group: group, sendContactProfilePicture: false)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self
            .deleteMessage = try? CspE2e_DeleteMessage(
                serializedData: container
                    .decode(Data.self, forKey: .deleteMessage)
            )
        self.editMessage = try? CspE2e_EditMessage(serializedData: container.decode(Data.self, forKey: .editMessage))

        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deleteMessage?.serializedData(), forKey: .deleteMessage)
        try container.encode(editMessage?.serializedData(), forKey: .editMessage)

        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }
}
