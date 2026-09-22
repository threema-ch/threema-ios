import Testing
import UIKit
@testable import Coordinator

@Suite("RouterPathHost", .serialized)
@MainActor
struct RouterPathHostTests {

    // MARK: - push

    @Test("Pushing onto an empty path appends the destination")
    func pushOntoEmptyPath() {
        let router = NavigationRouter()
        let host = RouterPathHost(router: router)

        host.push("a", animated: false)

        #expect(router.path == ["a"])
    }

    @Test("Pushing onto a non-empty path appends above the current top")
    func pushAppendsAboveTop() {
        let router = NavigationRouter()
        let host = RouterPathHost(router: router)

        host.push("a", animated: false)
        host.push("b", animated: false)

        #expect(router.path == ["a", "b"])
    }

    @Test("Pushing the destination already on top is a no-op")
    func pushSameAsTopIsNoOp() {
        let router = NavigationRouter()
        let host = RouterPathHost(router: router)

        host.push("a", animated: false)
        host.push("a", animated: false)

        #expect(router.path == ["a"])
    }

    // MARK: - pop

    @Test("Popping removes the top destination")
    func popRemovesTop() {
        let router = NavigationRouter()
        let host = RouterPathHost(router: router)
        host.push("a", animated: false)
        host.push("b", animated: false)

        host.pop(animated: false)

        #expect(router.path == ["a"])
    }

    @Test("Popping the last destination empties the path")
    func popToEmpty() {
        let router = NavigationRouter()
        let host = RouterPathHost(router: router)
        host.push("a", animated: false)

        host.pop(animated: false)

        #expect(router.path.isEmpty)
    }

    @Test("Popping an empty path is a no-op")
    func popEmptyPathIsNoOp() {
        let router = NavigationRouter()
        let host = RouterPathHost(router: router)

        host.pop(animated: false)

        #expect(router.path.isEmpty)
    }

    // MARK: - Screen builders

    @Test("A builder registered through the host materializes its own destinations")
    func registeredBuilderMaterializesScreen() throws {
        let fixture = BoundFixture()
        let builder = BuilderStub(owns: ["child"])
        fixture.host.registerScreenBuilder { builder.build($0) }

        fixture.host.push("child", animated: false)
        fixture.pump()

        #expect(fixture.router.path == ["child"])
        let screen = try #require(fixture.router.materializedViewController(for: "child"))
        #expect(fixture.navigationController.viewControllers.last === screen)
        #expect(builder.calls == ["child"])
    }

    @Test("Removing a builder through the host stops it from being consulted")
    func removedBuilderIsNoLongerConsulted() {
        let fixture = BoundFixture()
        let builder = BuilderStub(owns: ["child"])
        let token = fixture.host.registerScreenBuilder { builder.build($0) }

        fixture.host.removeScreenBuilder(token)
        fixture.host.push("child", animated: false)
        fixture.pump()

        // Nobody can build "child" anymore: the path self-heals back to empty and
        // the removed builder is never consulted.
        #expect(fixture.router.path.isEmpty)
        #expect(builder.calls.isEmpty)
        #expect(fixture.navigationController.viewControllers == [fixture.rootViewController])
    }

    // MARK: - Integration

    @Test("Push and pop drive the bound navigation stack end to end")
    func pushAndPopDriveBoundStack() {
        let fixture = BoundFixture()
        let builder = BuilderStub(owns: ["a", "b"])
        fixture.host.registerScreenBuilder { builder.build($0) }

        fixture.host.push("a", animated: false)
        fixture.pump()
        fixture.host.push("b", animated: false)
        fixture.pump()

        #expect(fixture.router.path == ["a", "b"])
        #expect(fixture.navigationController.viewControllers.count == 3)

        fixture.host.pop(animated: false)
        fixture.pump()

        #expect(fixture.router.path == ["a"])
        #expect(fixture.navigationController.viewControllers.count == 2)
        #expect(
            fixture.navigationController.viewControllers.last === fixture.router.materializedViewController(for: "a")
        )
    }
}

// MARK: - Test doubles

@MainActor
private final class BuilderStub {
    private(set) var calls: [AnyHashable] = []
    private let owned: Set<AnyHashable>

    init(owns owned: Set<AnyHashable>) {
        self.owned = owned
    }

    func build(_ destination: AnyHashable) -> UIViewController? {
        calls.append(destination)
        guard owned.contains(destination) else {
            return nil
        }
        let viewController = UIViewController()
        viewController.title = String(describing: destination.base)
        return viewController
    }
}

// MARK: - Fixture

/// A `RouterPathHost` over a `NavigationRouter` bound to a real
/// `UINavigationController` in a key window.
///
/// The owner builds nothing itself (`makeViewController` always returns `nil`),
/// so only screen builders registered *through the host* can materialize
/// screens — which is exactly what the builder-forwarding tests observe.
@MainActor
private struct BoundFixture {
    let window: UIWindow
    let navigationController: UINavigationController
    let rootViewController: UIViewController
    let router: NavigationRouter
    let host: RouterPathHost

    init() {
        // The package test bundle has no window scene, so real animated
        // transitions never complete. Disabling animations completes them
        // deterministically while preserving the delegate callback sequence.
        UIView.setAnimationsEnabled(false)

        let window = UIWindow(frame: UIScreen.main.bounds)
        let navigationController = UINavigationController()
        let rootViewController = UIViewController()
        rootViewController.title = "root"

        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let router = NavigationRouter()
        router.bind(
            to: navigationController,
            rootViewController: rootViewController,
            makeViewController: { _ in nil }
        )

        self.window = window
        self.navigationController = navigationController
        self.rootViewController = rootViewController
        self.router = router
        self.host = RouterPathHost(router: router)

        pump()
    }

    /// Lets pending navigation delegate callbacks and layout passes run.
    func pump(_ interval: TimeInterval = 0.05) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: interval))
    }
}
