import CocoaLumberjackSwift
import Foundation

/// Task definition must be codable to persists task definitions.
class TaskDefinition: NSObject, Codable, TaskDefinitionProtocol {
    var className: String { String(describing: Swift.type(of: self)) }

    var type: TaskType = .persistent
    var state: TaskExecutionState {
        didSet {
            isInterrupted = state == .interrupted
        }
    }

    @objc private(set) dynamic var isInterrupted = false

    /// Is this task dropped?
    ///
    /// This is similar to a cancel, but used for wording in line with Threema Protocol.
    ///
    /// This should only be set internally and only from the default `false` to `true`
    var isDropped = false {
        didSet {
            assert(isDropped, "This should only ever be set to `false`")
        }
    }
    
    var retry: Bool
    var retryCount: Int
    
    private enum CodingKeys: String, CodingKey {
        case state
        case retry
        case retryCount
    }
    
    init(type: TaskType) {
        self.type = type
        self.state = .pending
        self.retry = true
        self.retryCount = 0
    }

    func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        preconditionFailure("This function must be overridden")
    }

    func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        preconditionFailure("This function must be overridden")
    }
}
