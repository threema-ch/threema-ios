import CocoaLumberjackSwift
import Foundation
import ThreemaProtocols

final class TaskDefinitionSendCallOfferAnswerMessage: TaskDefinition, TaskDefinitionTransactionProtocol,
    TaskDefinitionSendMessageNonceProtocol,
    TaskDefinitionSendMessageProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendCallOfferAnswerMessage(
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

    var scope: D2d_TransactionScope.Scope {
        .o2OCall
    }
    
    let message: AbstractMessage
    let callID: VoIPCallID
    private var messageData: Data?

    var nonces = TaskReceiverNonce()

    private(set) var messageAlreadySentToQueue =
        DispatchQueue(label: "ch.threema.TaskDefinitionSendCallOfferAnswerMessage.messageAlreadySentToQueue")
    var messageAlreadySentTo = TaskReceiverNonce()

    private enum CodingKeys: String, CodingKey {
        case message, messageData, messageAlreadySentTo, callID
    }

    private enum CodingError: Error {
        case messageDataMissing
    }

    init(message: AbstractMessage, callID: VoIPCallID) {
        if !(message is BoxVoIPCallAnswerMessage ||
            message is BoxVoIPCallOfferMessage
        ) {
            DDLogWarn(
                "Only call offer and answer abstract messages for non-persisted messages should be send using this task (\(message.loggingDescription))"
            )
            assertionFailure()
        }
        
        self.message = message
        self.callID = callID
        super.init(type: .volatile)
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
