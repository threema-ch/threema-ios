import Testing
import UIKit
@testable import Threema

/// Exercises a real `UISplitViewController` in a key window. Compact and regular layouts are forced through
/// `traitOverrides`, so the suite runs the same on iPhone and iPad simulators.
@Suite("ThreemaTabSplitViewController", .serialized)
@MainActor
struct ThreemaTabSplitViewControllerTests {

    // MARK: - Appearance

    @Test("Compact width: the tab stack is bound to the primary column on appearance")
    func compactAppearanceBindsThePrimaryColumn() {
        let fixture = Fixture(horizontalSizeClass: .compact)

        // A compact first appearance is also UIKit's initial collapse; the two hooks must bind exactly once.
        #expect(fixture.recorder.events == [.activateCompact])
        #expect(fixture.splitViewController.isCompactLayout)
        #expect(fixture.splitViewController.isCollapsed)
        #expect(fixture.splitViewController.activeNavigationController === fixture.primaryNavigationController)
    }

    @Test("Returning to the tab after a tab switch binds again, so released screens are re-materialized")
    func reappearanceAfterTabSwitchBindsAgain() throws {
        let fixture = Fixture(horizontalSizeClass: .compact, inTabBarController: true)
        let tabBarController = try #require(fixture.tabBarController)
        let splitViewTab = tabBarController.tabs[0]
        let otherTab = tabBarController.tabs[1]

        tabBarController.selectedTab = otherTab
        fixture.pump()
        #expect(fixture.splitViewController.viewIfLoaded?.window == nil)

        tabBarController.selectedTab = splitViewTab
        fixture.pump()

        #expect(fixture.recorder.events == [.activateCompact, .activateCompact])
    }

    @Test("Regular width: the tab stack is bound into the owned secondary column on appearance")
    func regularAppearanceBindsTheSecondaryColumn() throws {
        let fixture = Fixture(horizontalSizeClass: .regular)
        let splitViewController = fixture.splitViewController

        #expect(fixture.recorder.events == [.activateRegular])
        #expect(!splitViewController.isCompactLayout)
        #expect(!splitViewController.isCollapsed)
        #expect(splitViewController.activeNavigationController === splitViewController.secondaryNavigationController)

        let column = try #require(fixture.recorder.lastSecondaryColumn)
        #expect(column.navigationController === splitViewController.secondaryNavigationController)
        #expect(column.placeholderViewController === fixture.placeholderViewController)
        #expect(splitViewController.secondaryNavigationController.viewControllers == [fixture.placeholderViewController])
        #expect(splitViewController.viewController(for: .primary) === fixture.primaryNavigationController)
        #expect(
            splitViewController.viewController(for: .secondary) === splitViewController.secondaryNavigationController
        )
    }

    @Test("A split view without a handle appears without binding anything")
    func appearanceWithoutHandleIsHarmless() {
        let fixture = Fixture(horizontalSizeClass: .compact, installHandle: false)

        #expect(fixture.recorder.events.isEmpty)
        #expect(fixture.splitViewController.isCollapsed)
    }

    // MARK: - Collapse and expand

    @Test("Collapsing unbinds, resets the secondary column to the placeholder and rebinds compact")
    func collapseResetsSecondaryAndBindsCompact() {
        let fixture = Fixture(horizontalSizeClass: .regular)
        let splitViewController = fixture.splitViewController
        let detail = UIViewController()
        splitViewController.secondaryNavigationController.setViewControllers([detail], animated: false)
        fixture.pump()

        fixture.setHorizontalSizeClass(.compact)

        #expect(splitViewController.isCollapsed)
        // Unbound before the column is reset, so a bound router never sees the reset as a user pop.
        #expect(fixture.recorder.events.suffix(2) == [.deactivate, .activateCompact])
        #expect(splitViewController.secondaryNavigationController.viewControllers == [fixture.placeholderViewController])
        #expect(splitViewController.activeNavigationController === fixture.primaryNavigationController)
    }

    @Test("Expanding unbinds, pops the primary column to its root and binds into the secondary column")
    func expandPopsPrimaryToRootAndBindsRegular() {
        let fixture = Fixture(horizontalSizeClass: .compact)
        let splitViewController = fixture.splitViewController
        let detail = UIViewController()
        fixture.primaryNavigationController.pushViewController(detail, animated: false)
        fixture.pump()

        fixture.setHorizontalSizeClass(.regular)

        #expect(!splitViewController.isCollapsed)
        #expect(fixture.recorder.events.suffix(2) == [.deactivate, .activateRegular])
        #expect(fixture.primaryNavigationController.viewControllers == [fixture.listViewController])
        #expect(splitViewController.activeNavigationController === splitViewController.secondaryNavigationController)
    }

    @Test("Collapse followed by expand round-trips the binding sequence")
    func collapseExpandRoundTrip() {
        let fixture = Fixture(horizontalSizeClass: .regular)

        fixture.setHorizontalSizeClass(.compact)
        fixture.setHorizontalSizeClass(.regular)

        #expect(
            fixture.recorder.events
                == [.activateRegular, .deactivate, .activateCompact, .deactivate, .activateRegular]
        )
    }

    @Test("The stack a compact binding pushes on collapse survives UIKit's own collapse of the columns")
    func collapseKeepsTheStackBoundCompact() {
        let fixture = Fixture(horizontalSizeClass: .regular)
        let splitViewController = fixture.splitViewController
        let detail = UIViewController()
        splitViewController.secondaryNavigationController.setViewControllers([detail], animated: false)
        fixture.pump()
        fixture.recorder.onActivateCompact = {
            fixture.primaryNavigationController.pushViewController(detail, animated: false)
        }

        fixture.setHorizontalSizeClass(.compact)

        #expect(splitViewController.isCollapsed)
        #expect(fixture.primaryNavigationController.viewControllers == [fixture.listViewController, detail])
        #expect(splitViewController.secondaryNavigationController.viewControllers == [fixture.placeholderViewController])
    }

    @Test("A width change while another tab is selected unbinds the regular binding before binding compact")
    func collapseOffScreenUnbindsTheRegularBinding() throws {
        let fixture = Fixture(horizontalSizeClass: .regular, inTabBarController: true)
        let splitViewController = fixture.splitViewController
        let tabBarController = try #require(fixture.tabBarController)
        let detail = UIViewController()
        splitViewController.secondaryNavigationController.setViewControllers([detail], animated: false)
        fixture.pump()

        tabBarController.selectedTab = tabBarController.tabs[1]
        fixture.pump()
        fixture.setHorizontalSizeClass(.compact)
        tabBarController.selectedTab = tabBarController.tabs[0]
        fixture.pump()

        #expect(splitViewController.isCollapsed)
        #expect(fixture.recorder.events == [.activateRegular, .deactivate, .activateCompact])
        #expect(splitViewController.secondaryNavigationController.viewControllers == [fixture.placeholderViewController])
    }

    // MARK: - Secondary column reset

    @Test("Resetting an already reset secondary column leaves the stack untouched")
    func resetSecondaryColumnIsIdempotent() {
        let fixture = Fixture(horizontalSizeClass: .regular)
        let splitViewController = fixture.splitViewController
        let detail = UIViewController()
        splitViewController.secondaryNavigationController.setViewControllers([detail], animated: false)

        splitViewController.resetSecondaryColumn()
        #expect(splitViewController.secondaryNavigationController.viewControllers == [fixture.placeholderViewController])

        splitViewController.resetSecondaryColumn()
        #expect(splitViewController.secondaryNavigationController.viewControllers == [fixture.placeholderViewController])
    }

    // MARK: - show(_:sender:)

    @Test("show(_:sender:) pushes onto the primary column while compact")
    func showPushesOntoPrimaryWhenCompact() {
        let fixture = Fixture(horizontalSizeClass: .compact)
        let shown = UIViewController()

        fixture.splitViewController.show(shown, sender: nil)
        fixture.pump()

        #expect(fixture.primaryNavigationController.viewControllers == [fixture.listViewController, shown])
        #expect(
            fixture.splitViewController.secondaryNavigationController.viewControllers == [
                fixture.placeholderViewController
            ]
        )
    }

    @Test("showDetailViewController(_:sender:) replaces the secondary column while regular")
    func showDetailReplacesSecondaryWhenRegular() {
        let fixture = Fixture(horizontalSizeClass: .regular)
        let shown = UIViewController()

        fixture.splitViewController.showDetailViewController(shown, sender: nil)
        fixture.pump()

        #expect(fixture.splitViewController.secondaryNavigationController.viewControllers == [shown])
        #expect(fixture.primaryNavigationController.viewControllers == [fixture.listViewController])
    }

    // MARK: - Tab bar visibility

    @Test("Compact: a screen that hides the bottom bar hides the tab bar, popping it shows the bar again")
    func compactHidesTabBarForScreensThatAskForIt() {
        let fixture = Fixture(horizontalSizeClass: .compact, inTabBarController: true)
        let chat = UIViewController()
        chat.hidesBottomBarWhenPushed = true

        fixture.primaryNavigationController.pushViewController(chat, animated: false)
        fixture.pump()

        #expect(fixture.tabBarController?.isTabBarHidden == true)

        fixture.primaryNavigationController.popViewController(animated: false)
        fixture.pump()

        #expect(fixture.tabBarController?.isTabBarHidden == false)
    }

    @Test("Compact: a screen pushed on top of one that hid the bar keeps it hidden")
    func compactKeepsTabBarHiddenAboveHidingScreen() {
        let fixture = Fixture(horizontalSizeClass: .compact, inTabBarController: true)
        let chat = UIViewController()
        chat.hidesBottomBarWhenPushed = true
        let details = UIViewController()

        fixture.primaryNavigationController.pushViewController(chat, animated: false)
        fixture.primaryNavigationController.pushViewController(details, animated: false)
        fixture.pump()

        #expect(fixture.tabBarController?.isTabBarHidden == true)
    }

    @Test("Regular: the tab bar never hides, even for screens that ask for it")
    func regularNeverHidesTabBar() {
        let fixture = Fixture(horizontalSizeClass: .regular, inTabBarController: true)
        let chat = UIViewController()
        chat.hidesBottomBarWhenPushed = true

        fixture.primaryNavigationController.pushViewController(chat, animated: false)
        fixture.pump()

        #expect(fixture.tabBarController?.isTabBarHidden == false)
    }

    @Test("Expanding with a hiding screen on the stack shows the tab bar again")
    func expandShowsTabBarAgain() {
        let fixture = Fixture(horizontalSizeClass: .compact, inTabBarController: true)
        let chat = UIViewController()
        chat.hidesBottomBarWhenPushed = true
        fixture.primaryNavigationController.pushViewController(chat, animated: false)
        fixture.pump()
        #expect(fixture.tabBarController?.isTabBarHidden == true)

        fixture.setHorizontalSizeClass(.regular)

        #expect(fixture.tabBarController?.isTabBarHidden == false)
    }

    @Test("An inactive tab's split view leaves the shared tab bar alone")
    func inactiveTabLeavesTabBarAlone() throws {
        let fixture = Fixture(horizontalSizeClass: .compact, inTabBarController: true)
        let tabBarController = try #require(fixture.tabBarController)
        let chat = UIViewController()
        chat.hidesBottomBarWhenPushed = true
        fixture.primaryNavigationController.pushViewController(chat, animated: false)
        fixture.pump()
        #expect(tabBarController.isTabBarHidden == true)

        // Another tab's split view under the same tab bar controller, without a screen that hides the bar (a size
        // transition reaches every tab, the selected one first)
        let inactive = ThreemaTabSplitViewController(
            tab: .profile,
            primaryNavigationController: UINavigationController(rootViewController: UIViewController()),
            placeholderViewController: UIViewController()
        )
        tabBarController.addChild(inactive)
        inactive.didMove(toParent: tabBarController)

        inactive.updateTabBarVisibility(animated: false)

        #expect(tabBarController.isTabBarHidden == true)
    }

    @Test("Navigation callbacks are forwarded to the navigation delegate after the tab bar update")
    func navigationCallbacksAreForwarded() {
        let fixture = Fixture(horizontalSizeClass: .compact, inTabBarController: true)
        let spy = NavigationDelegateSpy()
        fixture.splitViewController.navigationDelegate = spy
        let pushed = UIViewController()

        fixture.primaryNavigationController.pushViewController(pushed, animated: false)
        fixture.pump()

        #expect(spy.willShow.last === pushed)
        #expect(spy.didShow.last === pushed)
    }

    // MARK: - Modal presenter

    @Test("The modal presenter is the active column once it is on screen")
    func modalPresenterIsTheActiveColumnOnScreen() {
        let compact = Fixture(horizontalSizeClass: .compact)
        #expect(compact.splitViewController.modalPresenter === compact.primaryNavigationController)

        let regular = Fixture(horizontalSizeClass: .regular)
        #expect(regular.splitViewController.modalPresenter === regular.splitViewController.secondaryNavigationController)
    }

    @Test("The modal presenter falls back to the split view, then its parent, before the columns are on screen")
    func modalPresenterFallsBackOffScreen() {
        let primary = UINavigationController(rootViewController: UIViewController())
        let splitViewController = ThreemaTabSplitViewController(
            tab: .settings,
            primaryNavigationController: primary,
            placeholderViewController: UIViewController()
        )

        #expect(splitViewController.modalPresenter === splitViewController)

        let parent = UIViewController()
        parent.addChild(splitViewController)
        splitViewController.didMove(toParent: parent)

        #expect(splitViewController.modalPresenter === parent)
    }
}

// MARK: - Test doubles

@MainActor
private final class NavigationDelegateSpy: NSObject, UINavigationControllerDelegate {
    private(set) var willShow: [UIViewController] = []
    private(set) var didShow: [UIViewController] = []

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        willShow.append(viewController)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        didShow.append(viewController)
    }
}

@MainActor
private final class HandleRecorder {

    enum Event: Equatable {
        case deactivate
        case activateCompact
        case activateRegular
        case reauthenticate
        case release
    }

    private(set) var events: [Event] = []
    private(set) var lastSecondaryColumn: TabSecondaryColumn?

    /// Stands in for a router materializing its path on the compact binding
    var onActivateCompact: (() -> Void)?

    var handle: RouterManagedTabHandle {
        RouterManagedTabHandle(
            deactivate: { [weak self] in
                self?.events.append(.deactivate)
            },
            activateCompact: { [weak self] in
                self?.events.append(.activateCompact)
                self?.onActivateCompact?()
            },
            activateRegular: { [weak self] column in
                self?.events.append(.activateRegular)
                self?.lastSecondaryColumn = column
            },
            reauthenticateProtectedDestinations: { [weak self] in
                self?.events.append(.reauthenticate)
            },
            releaseMaterializedScreens: { [weak self] in
                self?.events.append(.release)
            }
        )
    }
}

// MARK: - Fixture

/// The split view is the window root, or (`inTabBarController`) the content of the first of two tabs of a
/// `UITabBarController` (the second tab holds a plain view controller to switch away to), with the split view
/// installed as the primary column's navigation delegate the way the routers forward to it in the app.
@MainActor
private struct Fixture {
    let window: UIWindow
    let splitViewController: ThreemaTabSplitViewController
    let tabBarController: UITabBarController?
    let primaryNavigationController: UINavigationController
    let listViewController: UIViewController
    let placeholderViewController: UIViewController
    let recorder: HandleRecorder

    init(
        horizontalSizeClass: UIUserInterfaceSizeClass,
        installHandle: Bool = true,
        inTabBarController: Bool = false
    ) {
        // Animated transitions never complete without a render server; disabling animations completes them
        // deterministically while preserving the delegate callback sequence.
        UIView.setAnimationsEnabled(false)

        let listViewController = UIViewController()
        listViewController.title = "list"
        let primaryNavigationController = UINavigationController(rootViewController: listViewController)
        let placeholderViewController = UIViewController()
        placeholderViewController.title = "placeholder"

        let splitViewController = ThreemaTabSplitViewController(
            tab: .conversations,
            primaryNavigationController: primaryNavigationController,
            placeholderViewController: placeholderViewController
        )
        let recorder = HandleRecorder()
        if installHandle {
            splitViewController.routerHandle = recorder.handle
        }
        splitViewController.traitOverrides.horizontalSizeClass = horizontalSizeClass

        let window = Self.makeWindow()
        var tabBarController: UITabBarController?
        if inTabBarController {
            let hostingTabBarController = UITabBarController()
            hostingTabBarController.tabs = [
                UITab(title: "Tab", image: nil, identifier: "test.tab") { _ in
                    splitViewController
                },
                UITab(title: "Other", image: nil, identifier: "test.other") { _ in
                    UIViewController()
                },
            ]
            primaryNavigationController.delegate = splitViewController
            window.rootViewController = hostingTabBarController
            tabBarController = hostingTabBarController
        }
        else {
            window.rootViewController = splitViewController
        }
        window.makeKeyAndVisible()

        self.window = window
        self.splitViewController = splitViewController
        self.tabBarController = tabBarController
        self.primaryNavigationController = primaryNavigationController
        self.listViewController = listViewController
        self.placeholderViewController = placeholderViewController
        self.recorder = recorder

        pump()
    }

    func setHorizontalSizeClass(_ sizeClass: UIUserInterfaceSizeClass) {
        splitViewController.traitOverrides.horizontalSizeClass = sizeClass
        pump()
    }

    /// Lets pending appearance callbacks, trait changes and layout passes run
    func pump(_ interval: TimeInterval = 0.1) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: interval))
    }

    private static func makeWindow() -> UIWindow {
        let frame = CGRect(x: 0, y: 0, width: 1024, height: 768)
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        guard let scene else {
            return UIWindow(frame: frame)
        }
        let window = UIWindow(windowScene: scene)
        window.frame = frame
        return window
    }
}
