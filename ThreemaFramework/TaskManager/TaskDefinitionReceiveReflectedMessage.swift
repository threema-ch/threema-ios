import Foundation
import ThreemaProtocols

final class TaskDefinitionReceiveReflectedMessage: TaskDefinition {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionReceiveReflectedMessage(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
        )
    }

    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        create(frameworkInjector: frameworkInjector, taskContext: TaskContext())
    }
    
    override var description: String {
        "<\(Swift.type(of: self))>"
    }
    
    required init(
        reflectedMessage: Data,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int
    ) {
        self.reflectedMessage = reflectedMessage
        self.maxBytesToDecrypt = Int32(maxBytesToDecrypt)
        self.timeoutDownloadThumbnail = Int32(timeoutDownloadThumbnail)
        self.receivedAfterInitialQueueSend = receivedAfterInitialQueueSend

        super.init(type: .dropOnDisconnect)
        self.retry = false
    }

    let reflectedMessage: Data
    let receivedAfterInitialQueueSend: Bool
    let maxBytesToDecrypt: Int32
    let timeoutDownloadThumbnail: Int32

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
