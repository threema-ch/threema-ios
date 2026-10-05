import ObjectiveC
import Testing
import UIKit
@testable import ThreemaFramework

@MainActor @Suite(.serialized)
struct UIWindowSecureTests {

    @Test(
        "A secured window outlives every view of its secure field",
        arguments: [true, false]
    )
    func windowOutlivesSecureFieldViews(showsPreventionView: Bool) async throws {
        let windowScene = try #require(Self.windowScene)
        let tracker = LifetimeTracker()
        weak var lifetime: UIWindow.WindowLifetime?

        autoreleasepool {
            let window = Self.makeSecuredWindow(
                windowScene: windowScene,
                showsPreventionView: showsPreventionView,
                tracker: tracker
            )
            let field = window.secureField
            #expect(Self.layer(window.layer, isInside: field?.layer))

            // Same teardown as `PasscodeCoordinator.reportSuccess()` and `CallCoordinator.finish()`
            window.isHidden = true
            window.removeSecure()

            #expect(window.secureField == nil)
            #expect(!Self.layer(window.layer, isInside: field?.layer))
            #expect(field?.superview == nil)
            #expect(field?.layer.superlayer == nil)

            lifetime = Self.expectWindowLifetime(of: window, onEveryViewOf: field, tracker: tracker)
        }

        // The lifetime must go away with the views (possibly already with the pool), otherwise the fix leaks the window
        let isAllReleased = try await Self.waitUntil { tracker.liveViewCount == 0 && lifetime == nil }
        #expect(isAllReleased, "Live views: \(tracker.liveViewNames), lifetime released: \(lifetime == nil)")
        #expect(tracker.viewsDeallocatedAfterWindow.isEmpty)
    }

    enum LateReleasedView: String, CaseIterable, CustomTestStringConvertible {
        /// The view that crashed in `-[UITextField dealloc]`
        case secureField
        /// The `ScreenshotPreventionView` host, deallocated through `_UIHostingView.deinit`
        case preventionView

        var testDescription: String {
            rawValue
        }
    }

    @Test(
        "A view of the secure field released after the window keeps the window alive",
        arguments: LateReleasedView.allCases
    )
    func lateReleasedViewKeepsWindowAlive(_ lateReleased: LateReleasedView) async throws {
        let windowScene = try #require(Self.windowScene)
        let tracker = LifetimeTracker()

        // Stands in for the Core Animation transaction that holds the detached field until it commits
        var lateReleasedView: UIView?
        weak var weakField: UITextField?
        weak var lifetime: UIWindow.WindowLifetime?

        autoreleasepool {
            let window = Self.makeSecuredWindow(
                windowScene: windowScene,
                showsPreventionView: true,
                tracker: tracker
            )
            let field = window.secureField
            weakField = field
            switch lateReleased {
            case .secureField:
                lateReleasedView = field
            case .preventionView:
                lateReleasedView = field?.leftView
            }

            window.isHidden = true
            window.removeSecure()

            lifetime = Self.expectWindowLifetime(of: window, onEveryViewOf: field, tracker: tracker)
        }

        try #require(lateReleasedView != nil)
        try #require(lifetime != nil)

        // Precondition: everything except the late view (and what it retains) is gone
        if lateReleased == .preventionView {
            let isFieldReleased = try await Self.waitUntil { weakField == nil }
            try #require(isFieldReleased, "Field still alive, live views: \(tracker.liveViewNames)")
        }
        try await Self.drainMainRunLoop()

        // The late view alone keeps the lifetime, and with it the window
        #expect(lifetime != nil)
        #expect(!tracker.isWindowDeallocated)

        lateReleasedView = nil

        let isAllReleased = try await Self.waitUntil { tracker.liveViewCount == 0 && lifetime == nil }
        #expect(isAllReleased, "Live views: \(tracker.liveViewNames), lifetime released: \(lifetime == nil)")
        #expect(tracker.viewsDeallocatedAfterWindow.isEmpty)
    }

    @Test("Removing twice or without securing first does nothing")
    func removeSecureIsIdempotent() throws {
        let windowScene = try #require(Self.windowScene)
        let window = UIWindow(windowScene: windowScene)

        window.removeSecure()
        #expect(window.secureField == nil)

        window.installSecureField(showsPreventionView: false)
        #expect(window.secureField != nil)

        window.removeSecure()
        window.removeSecure()
        #expect(window.secureField == nil)
        #expect(window.subviews.isEmpty)
    }

    // MARK: - Helpers

    private static var windowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
    }

    /// Mirrors `PasscodeWindow`: secured in init, then shown.
    private static func makeSecuredWindow(
        windowScene: UIWindowScene,
        showsPreventionView: Bool,
        tracker: LifetimeTracker
    ) -> UIWindow {
        let window = UIWindow(windowScene: windowScene)
        window.installSecureField(showsPreventionView: showsPreventionView)
        window.rootViewController = UIViewController()
        window.isHidden = false
        window.layoutIfNeeded()
        window.secureField?.layoutIfNeeded()

        tracker.track(window)
        if let field = window.secureField {
            tracker.track(subtreeOf: field)
            if let leftView = field.leftView, leftView.superview !== field {
                tracker.track(subtreeOf: leftView)
            }
        }

        return window
    }

    /// Expects every tracked view still attached to `field` to hold the same `WindowLifetime` of `window`.
    private static func expectWindowLifetime(
        of window: UIWindow,
        onEveryViewOf field: UITextField?,
        tracker: LifetimeTracker,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> UIWindow.WindowLifetime? {
        guard let field else {
            Issue.record("No secure field", sourceLocation: sourceLocation)
            return nil
        }

        let lifetime = UIWindow.windowLifetime(of: field)
        #expect(lifetime?.window === window, sourceLocation: sourceLocation)

        // A lifetime on the window or its own views would be a retain cycle that leaks the window
        let windowSideViews = Self.subtree(of: window)
        for view in windowSideViews where UIWindow.windowLifetime(of: view) != nil {
            Issue.record("\(type(of: view)) of the window keeps the window alive", sourceLocation: sourceLocation)
        }

        let attachedViews = tracker.liveViews.filter { view in
            view.isDescendant(of: field) || field.leftView.map { view.isDescendant(of: $0) } == true
        }
        for view in attachedViews {
            #expect(
                UIWindow.windowLifetime(of: view) === lifetime,
                "\(type(of: view)) does not keep the window alive",
                sourceLocation: sourceLocation
            )
        }

        return lifetime
    }

    /// `view` and all its real descendants.
    private static func subtree(of view: UIView) -> [UIView] {
        [view] + view.subviews.filter { $0.superview === view }.flatMap(subtree(of:))
    }

    private static func layer(_ layer: CALayer, isInside ancestor: CALayer?) -> Bool {
        var current = layer.superlayer
        // `makeSecure()` creates a layer cycle if the window's layer has no superlayer yet
        while let superlayer = current, superlayer !== layer {
            if superlayer === ancestor {
                return true
            }
            current = superlayer.superlayer
        }
        return false
    }

    /// Lets transactions commit, autorelease pools drain and main queue blocks run.
    private static func drainMainRunLoop() async throws {
        for _ in 0..<5 {
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Polls `condition` on the main run loop. Returns whether it became true within `timeout`.
    private static func waitUntil(
        timeout: Duration = .seconds(5),
        _ condition: () -> Bool
    ) async throws -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                return false
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        return true
    }
}

// MARK: - LifetimeTracker

/// Records whether a window was still alive when each tracked view finished deallocating.
@MainActor
private final class LifetimeTracker {
    private weak var window: UIWindow?
    private var trackedViews = Set<ObjectIdentifier>()
    private var liveViewNamesByID: [ObjectIdentifier: String] = [:]
    private let weakViews = NSHashTable<UIView>.weakObjects()

    private(set) var viewsDeallocatedAfterWindow: [String] = []

    var liveViewCount: Int {
        liveViewNamesByID.count
    }

    var liveViewNames: [String] {
        liveViewNamesByID.values.sorted()
    }

    var liveViews: [UIView] {
        weakViews.allObjects
    }

    var isWindowDeallocated: Bool {
        window == nil
    }

    func track(_ window: UIWindow) {
        self.window = window
    }

    func track(subtreeOf view: UIView) {
        let id = ObjectIdentifier(view)
        guard trackedViews.insert(id).inserted else {
            return
        }

        let name = String(describing: type(of: view))
        liveViewNamesByID[id] = name
        weakViews.add(view)
        let probe = DeallocProbe { [weak self] in
            guard let self else {
                return
            }
            liveViewNamesByID[id] = nil
            if window == nil {
                viewsDeallocatedAfterWindow.append(name)
            }
        }
        objc_setAssociatedObject(view, &DeallocProbe.key, probe, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // While secured the window's layer sits inside the field, so `subviews` (derived from the layer tree) also
        // lists the window. Only follow real children.
        view.subviews.filter { $0.superview === view }.forEach(track(subtreeOf:))
    }
}

/// Runs a closure when its owner releases its associated objects, which is after the owner's `dealloc` ran.
private final class DeallocProbe {
    nonisolated(unsafe) static var key: UInt8 = 0

    private let onDeinit: @MainActor () -> Void

    init(onDeinit: @escaping @MainActor () -> Void) {
        self.onDeinit = onDeinit
    }

    deinit {
        MainActor.assumeIsolated {
            onDeinit()
        }
    }
}
