/// Seam over `LaunchModalManager` so `AppCoordinator`'s launch flow can be tested without
/// presenting real launch modals. Kept local to `AppCoordinator` (init parameter, not
/// `AppDependencyContainer`): the launch modals are only triggered from here.
@MainActor
protocol LaunchModalManagerProtocol {
    func checkLaunchModals()
}

// MARK: - LaunchModalManager + LaunchModalManagerProtocol

extension LaunchModalManager: LaunchModalManagerProtocol { }
