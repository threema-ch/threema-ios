import libthreemaSwift

/// Resolve the `RemoteSecretCreateTaskProtocol` used at runtime
protocol RemoteSecretCreateTaskResolver {
    func createNewTask(with context: RemoteSecretSetupContext) throws -> any RemoteSecretCreateTaskProtocol
}

// MARK: - Default implementation

struct DefaultRemoteSecretCreateTaskResolver: RemoteSecretCreateTaskResolver {
    func createNewTask(with context: RemoteSecretSetupContext) throws -> any RemoteSecretCreateTaskProtocol {
        try RemoteSecretCreateTask(context: context)
    }
}
