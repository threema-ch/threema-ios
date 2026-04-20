import Foundation

@objc final class TaskDefinitionReceiveMessage: TaskDefinition {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionReceiveMessage(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
        )
    }

    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        create(frameworkInjector: frameworkInjector, taskContext: TaskContext())
    }
    
    override var description: String {
        "<\(Swift.type(of: self)) \(message?.loggingDescription ?? "unknown message")>"
    }
    
    @objc private init(message: BoxedMessage) {
        super.init(type: .dropOnDisconnect)
        self.retry = false
        self.message = message
    }
    
    @objc convenience init(
        message: BoxedMessage,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int
    ) {
        self.init(message: message)
        self.receivedAfterInitialQueueSend = receivedAfterInitialQueueSend
        self.maxBytesToDecrypt = Int32(maxBytesToDecrypt)
        self.timeoutDownloadThumbnail = Int32(timeoutDownloadThumbnail)
    }
    
    var message: BoxedMessage!
    var receivedAfterInitialQueueSend: Bool!
    var maxBytesToDecrypt: Int32!
    var timeoutDownloadThumbnail: Int32!
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
