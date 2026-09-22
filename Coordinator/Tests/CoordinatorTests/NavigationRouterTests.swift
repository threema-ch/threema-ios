import Testing
import UIKit
@testable import Coordinator

@Suite("NavigationRouter", .serialized)
@MainActor
struct NavigationRouterTests {

    // MARK: - State → UI

    @Test("Binding with an empty path shows only the root screen")
    func bindShowsOnlyRootForEmptyPath() {
        let fixture = Fixture()

        #expect(fixture.navigationController.viewControllers == [fixture.rootViewController])
        #expect(fixture.router.path.isEmpty)
        #expect(fixture.factory.makeCalls.isEmpty)
    }

    @Test("Setting a one-element path pushes its screen onto the root")
    func setPathPushesScreen() {
        let fixture = Fixture()

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()

        #expect(fixture.router.path == ["a"])
        #expect(fixture.navigationController.viewControllers.count == 2)
        #expect(fixture.navigationController.viewControllers.first == fixture.rootViewController)
        #expect(fixture.factory.makeCalls == ["a"])
    }

    @Test("Growing the path reuses already-materialized screens")
    func growingPathReusesMaterializedScreens() {
        let fixture = Fixture()

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()
        let screenA = fixture.navigationController.viewControllers[1]

        fixture.router.setPath(["a", "b"], animated: false)
        fixture.pump()

        #expect(fixture.router.path == ["a", "b"])
        #expect(fixture.navigationController.viewControllers.count == 3)
        // The screen for "a" must be reused, not rebuilt.
        #expect(fixture.navigationController.viewControllers[1] === screenA)
        #expect(fixture.factory.makeCalls == ["a", "b"])
    }

    @Test("Setting a shorter prefix path pops back to it")
    func shorterPathPops() {
        let fixture = Fixture()

        fixture.router.setPath(["a", "b", "c"], animated: false)
        fixture.pump()
        let screenA = fixture.navigationController.viewControllers[1]

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()

        #expect(fixture.router.path == ["a"])
        #expect(fixture.navigationController.viewControllers == [fixture.rootViewController, screenA])
    }

    @Test("Setting a disjoint path replaces the whole stack")
    func disjointPathReplacesStack() {
        let fixture = Fixture()

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()

        fixture.router.setPath(["b", "c"], animated: false)
        fixture.pump()

        #expect(fixture.router.path == ["b", "c"])
        #expect(fixture.navigationController.viewControllers.count == 3)
        #expect(fixture.factory.makeCalls == ["a", "b", "c"])
    }

    @Test("Setting the identical path is a no-op")
    func settingSamePathIsNoOp() {
        let fixture = Fixture()

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()
        let stack = fixture.navigationController.viewControllers

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()

        #expect(fixture.navigationController.viewControllers == stack)
        // "a" was materialized exactly once.
        #expect(fixture.factory.makeCalls == ["a"])
    }

    @Test("Setting an empty path pops everything back to the root")
    func emptyPathPopsToRoot() {
        let fixture = Fixture()

        fixture.router.setPath(["a", "b"], animated: false)
        fixture.pump()

        fixture.router.setPath([], animated: false)
        fixture.pump()

        #expect(fixture.navigationController.viewControllers == [fixture.rootViewController])
        #expect(fixture.router.path.isEmpty)
    }

    // MARK: - Self-healing

    @Test("A destination that fails to materialize truncates the path there")
    func unresolvableDestinationTruncatesPath() {
        let fixture = Fixture()
        fixture.factory.unresolvable = ["b"]

        fixture.router.setPath(["a", "b", "c"], animated: false)
        fixture.pump()

        // "b" cannot materialize: it and everything above it are dropped.
        #expect(fixture.router.path == ["a"])
        #expect(fixture.navigationController.viewControllers.count == 2)
        // "c" was never even attempted.
        #expect(fixture.factory.makeCalls == ["a", "b"])
    }

    @Test("Invalidating a materialized screen forces its recreation")
    func invalidateMaterializedScreenForcesRecreation() throws {
        let fixture = Fixture()

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()
        let firstScreen = try #require(fixture.router.materializedViewController(for: "a"))

        fixture.router.invalidateMaterializedScreen(for: "a")
        fixture.router.setPath([], animated: false)
        fixture.pump()
        fixture.router.setPath(["a"], animated: false)
        fixture.pump()

        let secondScreen = try #require(fixture.router.materializedViewController(for: "a"))
        #expect(firstScreen !== secondScreen)
        #expect(fixture.factory.makeCalls == ["a", "a"])
    }

    // MARK: - UI → State (reconciliation)

    @Test("A user pop trims the path and notifies the delegate")
    func userPopReconcilesPath() {
        let fixture = Fixture()

        fixture.router.setPath(["a", "b"], animated: false)
        fixture.pump()

        fixture.navigationController.popViewController(animated: false)
        fixture.pump()

        #expect(fixture.router.path == ["a"])
        #expect(fixture.delegate.didPopToPaths.last == ["a"])
    }

    @Test("A user pop to root empties the path")
    func userPopToRootReconcilesToEmptyPath() {
        let fixture = Fixture()

        fixture.router.setPath(["a", "b", "c"], animated: false)
        fixture.pump()

        fixture.navigationController.popToRootViewController(animated: false)
        fixture.pump()

        #expect(fixture.router.path.isEmpty)
        #expect(fixture.delegate.didPopToPaths.last == [])
    }

    @Test("A screen pushing its own sub-screen does not corrupt the path")
    func foreignPushIsToleratedAndReconciledAway() {
        let fixture = Fixture()

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()

        // A screen pushes its own sub-screen, bypassing the router.
        let foreign = UIViewController()
        fixture.navigationController.pushViewController(foreign, animated: false)
        fixture.pump()

        // The path must not change because of the unknown screen.
        #expect(fixture.router.path == ["a"])

        fixture.navigationController.popViewController(animated: false)
        fixture.pump()

        #expect(fixture.router.path == ["a"])
        #expect(fixture.navigationController.viewControllers.count == 2)
    }

    // MARK: - Re-binding

    @Test("Re-binding materializes the existing path into the new navigation controller")
    func rebindMaterializesPathIntoNewNavigationController() {
        let fixture = Fixture()

        fixture.router.setPath(["a", "b"], animated: false)
        fixture.pump()
        let screenA = fixture.router.materializedViewController(for: "a")

        let secondNavigationController = UINavigationController()
        fixture.window.rootViewController = secondNavigationController
        fixture.router.bind(
            to: secondNavigationController,
            rootViewController: fixture.rootViewController,
            makeViewController: { [factory = fixture.factory] in factory.make($0) }
        )
        fixture.pump()

        #expect(fixture.router.path == ["a", "b"])
        #expect(secondNavigationController.viewControllers.count == 3)
        // Materialized screens survive the re-bind.
        #expect(secondNavigationController.viewControllers[1] === screenA)
        #expect(fixture.factory.makeCalls == ["a", "b"])
    }

    @Test("Unbinding keeps the path but stops touching the navigation controller")
    func unbindKeepsPathAndStopsApplying() {
        let fixture = Fixture()

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()

        fixture.router.unbind()
        fixture.router.setPath(["a", "b"], animated: false)
        fixture.pump()

        // Path is stored, but the detached navigation controller is untouched.
        #expect(fixture.router.path == ["a", "b"])
        #expect(fixture.navigationController.viewControllers.count == 2)
        #expect(!fixture.router.isBound)
    }

    @Test("Pops on a navigation controller the router detached from are ignored")
    func popOnUnboundNavigationControllerDoesNotReconcile() {
        let fixture = Fixture()

        fixture.router.setPath(["a", "b"], animated: false)
        fixture.pump()

        fixture.router.unbind()
        fixture.navigationController.popViewController(animated: false)
        fixture.pump()

        // The pop happened while detached; the path (the source of truth for the
        // next bind) must survive.
        #expect(fixture.router.path == ["a", "b"])
    }

    // MARK: - Placeholder root mode

    @Test("Placeholder mode shows the placeholder only while the path is empty")
    func placeholderIsShownOnlyWhilePathIsEmpty() {
        let fixture = Fixture(rootMode: .placeholder)

        #expect(fixture.navigationController.viewControllers == [fixture.rootViewController])

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()

        // The first path element is the actual root — no placeholder below it,
        // so it can never show a back button.
        #expect(fixture.navigationController.viewControllers.count == 1)
        #expect(fixture.navigationController.viewControllers.first != fixture.rootViewController)

        fixture.router.setPath([], animated: false)
        fixture.pump()

        #expect(fixture.navigationController.viewControllers == [fixture.rootViewController])
    }

    @Test("Placeholder mode keeps the first path element as root for deep paths")
    func placeholderModeDeepPathKeepsFirstElementAsRoot() {
        let fixture = Fixture(rootMode: .placeholder)

        fixture.router.setPath(["a", "b"], animated: false)
        fixture.pump()

        #expect(fixture.navigationController.viewControllers.count == 2)
        #expect(
            fixture.navigationController.viewControllers[0]
                === fixture.router.materializedViewController(for: "a")
        )

        fixture.navigationController.popViewController(animated: false)
        fixture.pump()

        #expect(fixture.router.path == ["a"])
    }

    // MARK: - Transition queueing

    @Test("Mutations during a running transition are deferred and the latest path wins")
    func mutationDuringTransitionIsDeferredAndCoalesced() {
        let fixture = Fixture()

        fixture.router.setPath(["a"], animated: false)
        fixture.pump()
        let stackDuringTransition = fixture.navigationController.viewControllers

        // A transition is now "running".
        fixture.navigationController.stubbedTransitionCoordinator = FakeTransitionCoordinator()

        fixture.router.setPath(["a", "b"], animated: false)
        fixture.router.setPath(["c"], animated: false)

        // Both mutations are deferred: the visible stack is untouched and no new
        // screen was materialized, but the path already reflects the latest intent.
        #expect(fixture.navigationController.viewControllers == stackDuringTransition)
        #expect(fixture.router.path == ["c"])
        #expect(fixture.factory.makeCalls == ["a"])

        // The transition ends; the deferred apply drains on the next turn.
        fixture.navigationController.stubbedTransitionCoordinator = nil
        fixture.pump()

        #expect(fixture.router.path == ["c"])
        #expect(fixture.navigationController.viewControllers.count == 2)
        #expect(
            fixture.navigationController.viewControllers[1]
                === fixture.router.materializedViewController(for: "c")
        )
        // The intermediate "b" path was coalesced away — never materialized.
        #expect(fixture.factory.makeCalls == ["a", "c"])
    }
}

// MARK: - Test doubles

/// A navigation controller whose "transition in flight" signal is controllable,
/// because the render-server-less test host cannot run real animated
/// transitions to completion.
private final class TransitionStubNavigationController: UINavigationController {
    var stubbedTransitionCoordinator: UIViewControllerTransitionCoordinator?

    override var transitionCoordinator: UIViewControllerTransitionCoordinator? {
        stubbedTransitionCoordinator ?? super.transitionCoordinator
    }
}

/// Minimal coordinator stand-in; the router only checks presence and
/// `isInteractive`.
@MainActor
private final class FakeTransitionCoordinator: NSObject, UIViewControllerTransitionCoordinator {
    var isAnimated: Bool { true }
    var presentationStyle: UIModalPresentationStyle { .none }
    var initiallyInteractive: Bool { false }
    var isInterruptible: Bool { false }
    var isInteractive: Bool { false }
    var isCancelled: Bool { false }
    var transitionDuration: TimeInterval { 0.35 }
    var percentComplete: CGFloat { 0 }
    var completionVelocity: CGFloat { 1 }
    var completionCurve: UIView.AnimationCurve { .easeInOut }
    var containerView: UIView { UIView() }
    var targetTransform: CGAffineTransform { .identity }

    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? { nil }
    func view(forKey key: UITransitionContextViewKey) -> UIView? { nil }

    func animate(
        alongsideTransition animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?,
        completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)? = nil
    ) -> Bool { false }

    func animateAlongsideTransition(
        in view: UIView?,
        animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?,
        completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)? = nil
    ) -> Bool { false }

    func notifyWhenInteractionEnds(
        _ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void
    ) { }

    func notifyWhenInteractionChanges(
        _ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void
    ) { }
}

@MainActor
private final class ScreenFactoryStub {
    private(set) var makeCalls: [AnyHashable] = []
    /// Destinations that fail to materialize (simulates deleted entities).
    var unresolvable: Set<AnyHashable> = []

    func make(_ destination: AnyHashable) -> UIViewController? {
        makeCalls.append(destination)
        guard !unresolvable.contains(destination) else {
            return nil
        }
        let viewController = UIViewController()
        viewController.title = String(describing: destination.base)
        return viewController
    }
}

@MainActor
private final class RouterDelegateSpy: NavigationRouterDelegate {
    private(set) var didPopToPaths: [[AnyHashable]] = []

    func router(_ router: NavigationRouter, didPopTo path: [AnyHashable]) {
        didPopToPaths.append(path)
    }
}

// MARK: - Fixture

@MainActor
private struct Fixture {
    let window: UIWindow
    let navigationController: TransitionStubNavigationController
    let rootViewController: UIViewController
    let router: NavigationRouter
    let factory: ScreenFactoryStub
    let delegate: RouterDelegateSpy

    init(rootMode: NavigationRouter.RootMode = .screen) {
        // The test bundle has no window scene, so real animations never advance
        // (no render server) and an animated transition would stay "in flight"
        // forever — deadlocking anything deferred behind it. Disabling
        // animations completes transitions deterministically while preserving
        // the delegate callback sequence.
        UIView.setAnimationsEnabled(false)

        let window = UIWindow(frame: UIScreen.main.bounds)
        let navigationController = TransitionStubNavigationController()
        let rootViewController = UIViewController()
        rootViewController.title = "root"

        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let factory = ScreenFactoryStub()
        let delegate = RouterDelegateSpy()

        let router = NavigationRouter()
        router.delegate = delegate
        router.bind(
            to: navigationController,
            rootViewController: rootViewController,
            rootMode: rootMode,
            makeViewController: { factory.make($0) }
        )

        self.window = window
        self.navigationController = navigationController
        self.rootViewController = rootViewController
        self.router = router
        self.factory = factory
        self.delegate = delegate

        pump()
    }

    /// Lets pending navigation delegate callbacks and layout passes run.
    func pump(_ interval: TimeInterval = 0.05) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: interval))
    }
}
