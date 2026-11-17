import Testing
import UIKit
@testable import Threema

/// Exercises a real `UITabBarController` in a key window with plain view controllers as tab content; the
/// router-managed handles are recorders.
@Suite("ThreemaTabBarController", .serialized)
@MainActor
struct ThreemaTabBarControllerTests {

    // MARK: - Configuration

    @Test("Tabs are installed in tab order with the stable identifiers, tab bar mode, conversations selected")
    func configurationInstallsTabsInOrder() {
        let fixture = Fixture()
        let tabBarController = fixture.tabBarController

        #expect(tabBarController.tabs.map(\.identifier) == ThreemaTab.allCases.map(\.identifier))
        #expect(tabBarController.mode == .tabBar)
        #expect(tabBarController.selectedThreemaTab == .conversations)
        #expect(tabBarController.selectedTab?.identifier == ThreemaTab.conversations.identifier)
        #expect(tabBarController.selectedViewController === fixture.viewControllers[.conversations])
        #expect(fixture.events(for: .conversations).isEmpty)
    }

    // MARK: - Programmatic selection

    @Test("A programmatic switch selects the tab and re-authenticates it exactly once")
    func programmaticSwitchSelectsAndReauthenticatesOnce() {
        let fixture = Fixture()

        fixture.tabBarController.select(.profile)

        #expect(fixture.tabBarController.selectedThreemaTab == .profile)
        #expect(fixture.tabBarController.selectedViewController === fixture.viewControllers[.profile])
        // Re-authentication presents on the entered tab in the same turn: its view must already be on screen.
        #expect(fixture.viewControllers[.profile]?.viewIfLoaded?.window != nil)
        #expect(fixture.events(for: .profile) == [.reauthenticate])

        fixture.tabBarController.select(.profile)

        #expect(fixture.events(for: .profile) == [.reauthenticate])
    }

    @Test("Returning to a tab the user left re-authenticates that tab")
    func returningToALeftTabReauthenticates() {
        let fixture = Fixture()

        fixture.tabBarController.select(.settings)
        fixture.tabBarController.select(.conversations)

        #expect(fixture.events(for: .conversations) == [.reauthenticate])
        #expect(fixture.events(for: .settings) == [.reauthenticate])
        #expect(fixture.events(for: .contacts).isEmpty)
    }

    // MARK: - User selection (delegate)

    @Test("UIKit performs a tap on another tab; the didSelect report switches the state and re-authenticates once")
    func userTapIsReportedOnceSelected() throws {
        let fixture = Fixture()
        let tabBarController = fixture.tabBarController
        let profileTab = try #require(tabBarController.tab(forIdentifier: ThreemaTab.profile.identifier))
        let conversationsTab = tabBarController.tab(forIdentifier: ThreemaTab.conversations.identifier)

        // What UIKit does for a tap before it reports the selection
        tabBarController.selectedTab = profileTab
        fixture.pump()
        tabBarController.tabBarController(tabBarController, didSelectTab: profileTab, previousTab: conversationsTab)

        #expect(tabBarController.selectedThreemaTab == .profile)
        #expect(fixture.viewControllers[.profile]?.viewIfLoaded?.window != nil)
        #expect(fixture.events(for: .profile) == [.reauthenticate])

        tabBarController.tabBarController(tabBarController, didSelectTab: profileTab, previousTab: conversationsTab)

        #expect(fixture.events(for: .profile) == [.reauthenticate])
    }

    @Test("Re-tapping the selected tab is left to UIKit (pop to root) and never re-authenticates")
    func reTapIsLeftToUIKit() throws {
        let fixture = Fixture()
        let tabBarController = fixture.tabBarController
        let conversationsTab = try #require(tabBarController.tab(forIdentifier: ThreemaTab.conversations.identifier))

        tabBarController.tabBarController(tabBarController, didSelectTab: conversationsTab, previousTab: nil)

        #expect(tabBarController.selectedThreemaTab == .conversations)
        #expect(fixture.events(for: .conversations).isEmpty)
    }

    @Test("Tab content switches in place: the transition between tabs has no duration")
    func tabTransitionIsInstant() throws {
        let fixture = Fixture()
        let tabBarController = fixture.tabBarController
        let from = try #require(fixture.viewControllers[.conversations])
        let to = try #require(fixture.viewControllers[.profile])

        let animator = tabBarController.tabBarController(
            tabBarController,
            animationControllerForTransitionFrom: from,
            to: to
        )

        #expect(animator?.transitionDuration(using: nil) == 0)
    }

    // MARK: - Memory warning

    @Test("A memory warning releases only the inactive tabs")
    func memoryWarningReleasesOnlyInactiveTabs() {
        let fixture = Fixture()
        fixture.tabBarController.select(.settings)

        fixture.tabBarController.releaseInactiveTabs()

        #expect(fixture.events(for: .contacts) == [.release])
        #expect(fixture.events(for: .conversations) == [.release])
        #expect(fixture.events(for: .profile) == [.release])
        #expect(fixture.events(for: .settings) == [.reauthenticate])
    }

    // MARK: - Badge

    @Test("The badge is set and cleared on the tab")
    func badgeIsSetOnTheTab() {
        let fixture = Fixture()
        let tabBarController = fixture.tabBarController

        tabBarController.setBadge("3", for: .conversations)
        #expect(tabBarController.tab(forIdentifier: ThreemaTab.conversations.identifier)?.badgeValue == "3")

        tabBarController.setBadge(nil, for: .conversations)
        #expect(tabBarController.tab(forIdentifier: ThreemaTab.conversations.identifier)?.badgeValue == nil)
    }

    // MARK: - Reset

    @Test("Reset removes the tabs and forgets the handles")
    func resetRemovesTabsAndHandles() {
        let fixture = Fixture()

        fixture.tabBarController.reset()
        fixture.tabBarController.releaseInactiveTabs()

        #expect(fixture.tabBarController.tabs.isEmpty)
        for tab in ThreemaTab.allCases {
            #expect(fixture.events(for: tab).isEmpty)
        }
    }
}

// MARK: - Test doubles

@MainActor
private final class HandleRecorder {

    enum Event: Equatable {
        case deactivate
        case activateCompact
        case activateRegular
        case reauthenticate
        case release
    }

    private(set) var events: [ThreemaTab: [Event]] = [:]

    func handle(for tab: ThreemaTab) -> RouterManagedTabHandle {
        RouterManagedTabHandle(
            deactivate: { [weak self] in
                self?.events[tab, default: []].append(.deactivate)
            },
            activateCompact: { [weak self] in
                self?.events[tab, default: []].append(.activateCompact)
            },
            activateRegular: { [weak self] _ in
                self?.events[tab, default: []].append(.activateRegular)
            },
            reauthenticateProtectedDestinations: { [weak self] in
                self?.events[tab, default: []].append(.reauthenticate)
            },
            releaseMaterializedScreens: { [weak self] in
                self?.events[tab, default: []].append(.release)
            }
        )
    }
}

// MARK: - Fixture

@MainActor
private struct Fixture {
    let window: UIWindow
    let tabBarController: ThreemaTabBarController
    let viewControllers: [ThreemaTab: UIViewController]
    let recorder: HandleRecorder

    init(horizontalSizeClass: UIUserInterfaceSizeClass? = nil) {
        UIView.setAnimationsEnabled(false)

        var viewControllers: [ThreemaTab: UIViewController] = [:]
        for tab in ThreemaTab.allCases {
            let viewController = UIViewController()
            viewController.title = tab.identifier
            viewControllers[tab] = viewController
        }

        let tabBarController = ThreemaTabBarController()
        tabBarController.configureTabs(viewControllers)
        if let horizontalSizeClass {
            tabBarController.traitOverrides.horizontalSizeClass = horizontalSizeClass
        }

        let recorder = HandleRecorder()
        for tab in ThreemaTab.allCases {
            tabBarController.registerRouterManagedTab(tab, handle: recorder.handle(for: tab))
        }

        let window = Self.makeWindow()
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()

        self.window = window
        self.tabBarController = tabBarController
        self.viewControllers = viewControllers
        self.recorder = recorder

        pump()
    }

    func events(for tab: ThreemaTab) -> [HandleRecorder.Event] {
        recorder.events[tab] ?? []
    }

    /// Lets pending appearance callbacks and layout passes run
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
