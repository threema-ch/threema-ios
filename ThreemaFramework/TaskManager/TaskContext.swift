import Foundation

protocol TaskContextProtocol {
    var logReflectMessageToMediator: LoggingTag { get }
    var logReceiveMessageAckFromMediator: LoggingTag { get }
    var logSendMessageToChat: LoggingTag { get }
    var logReceiveMessageAckFromChat: LoggingTag { get }
    /// Timeout (in seconds) waiting for a mediator transaction lock/unlock acknowledgement.
    /// Defaults to 25 s in production; override in tests to fail fast.
    var transactionResponseTimeoutInSeconds: Int { get }
}

final class TaskContext: TaskContextProtocol {
    var logReflectMessageToMediator: LoggingTag
    var logReceiveMessageAckFromMediator: LoggingTag
    var logSendMessageToChat: LoggingTag
    var logReceiveMessageAckFromChat: LoggingTag
    var transactionResponseTimeoutInSeconds: Int

    required init(
        logReflectMessageToMediator: LoggingTag,
        logReceiveMessageAckFromMediator: LoggingTag,
        logSendMessageToChat: LoggingTag,
        logReceiveMessageAckFromChat: LoggingTag,
        transactionResponseTimeoutInSeconds: Int = 25
    ) {
        self.logReflectMessageToMediator = logReflectMessageToMediator
        self.logReceiveMessageAckFromMediator = logReceiveMessageAckFromMediator
        self.logSendMessageToChat = logSendMessageToChat
        self.logReceiveMessageAckFromChat = logReceiveMessageAckFromChat
        self.transactionResponseTimeoutInSeconds = transactionResponseTimeoutInSeconds
    }

    required convenience init() {
        self.init(
            logReflectMessageToMediator: .none,
            logReceiveMessageAckFromMediator: .none,
            logSendMessageToChat: .none,
            logReceiveMessageAckFromChat: .none
        )
    }
}
