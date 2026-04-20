/// Task to disable multi-device if there are no other devices left in the group
///
/// You should never create such a task on your own. Use `MultiDeviceManagerProtocol.disableMultiDeviceIfNeeded()`
/// instead.
///
/// This is implemented as a task such that it is executed when a server connection exists and no other task is
/// executed. It is expected when this task disables MD that the task will be marked as dropped (because disabling MD
/// leads to a disconnect).
final class TaskDefinitionDisableMultiDeviceIfNeeded: TaskDefinition {
    override func create(
        frameworkInjector: any FrameworkInjectorProtocol,
        taskContext: any TaskContextProtocol
    ) -> any TaskExecutionProtocol {
        TaskExecutionDisableMultiDeviceIfNeeded(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
        )
    }
    
    override func create(frameworkInjector: any FrameworkInjectorProtocol) -> any TaskExecutionProtocol {
        create(
            frameworkInjector: frameworkInjector,
            taskContext: TaskContext(
                logReflectMessageToMediator: .none,
                logReceiveMessageAckFromMediator: .none,
                logSendMessageToChat: .none,
                logReceiveMessageAckFromChat: .none
            )
        )
    }
    
    override var description: String {
        "<\(Swift.type(of: self))>"
    }
    
    init() {
        super.init(type: .dropOnDisconnect)
    }
    
    required init(from decoder: any Decoder) throws {
        fatalError("This task should never be persisted")
    }
}
