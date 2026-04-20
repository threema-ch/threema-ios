import Foundation

/// It is mainly useful for mocking `BusinessInjector` for unit tests.
protocol FrameworkInjectorResolverProtocol {
    var backgroundFrameworkInjector: FrameworkInjectorProtocol { get }
}

final class FrameworkInjectorResolver: FrameworkInjectorResolverProtocol {
    private let entityManager: EntityManager?

    init(backgroundEntityManager: EntityManager?) {
        assert(
            backgroundEntityManager?.hasBackgroundChildContext ?? true,
            "Must be an EntityManager for a background thread"
        )

        self.entityManager = backgroundEntityManager
    }

    /// Get new `BusinessInjector` for background processing (new `EntityManager` with new child context)
    /// or use `EntityManager` which is applied in the initializer (e.g. from Notification Extension).
    var backgroundFrameworkInjector: FrameworkInjectorProtocol {
        if let entityManager {
            return BusinessInjector(entityManager: entityManager)
        }
        return BusinessInjector(forBackgroundProcess: true)
    }
}
