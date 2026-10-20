import Coordinator
import SwiftUI
import UIKit

// MARK: - Demo: child coordinators pushing onto a shared path
//
// Reachable from Settings via `SettingsCoordinator.InternalDestination.coordinatorDemo`.
//
// The point of this example: a whole *tree* of child coordinators can drive one
// navigation stack that none of them own. `SettingsCoordinator` owns the only
// `NavigationRouter`; every coordinator below just talks to the `PathHost`
// surface — it pushes its screen and registers how to build it. Because each
// step is a real path element, back / swipe-back / pop-to-root work across the
// whole chain for free.
//
//   SettingsCoordinator (owns the router)
//   └── DemoFlowCoordinator (owns the chain, no router)
//       ├── DemoStepCoordinator #0  → red screen,   "Next"
//       ├── DemoStepCoordinator #1  → green screen, "Next"
//       └── DemoStepCoordinator #2  → blue screen,  "Done"

/// Root of the demo. Owns one child coordinator per step and advances the chain
/// when a step asks for the next one.
@MainActor
final class DemoFlowCoordinator: NSObject, Coordinator {

    // MARK: - Coordinator

    var childCoordinators: [any Coordinator] = []

    /// Unused for a hosted child — it renders into the host's navigation stack
    /// and is never embedded itself. Present only to satisfy `Coordinator`.
    lazy var rootViewController: UIViewController = UIViewController()

    // MARK: - Private properties

    private unowned let host: any PathHost

    private let steps: [(title: String, color: Color)] = [
        ("Step 1", .red),
        ("Step 2", .green),
        ("Step 3", .blue),
    ]

    // MARK: - Lifecycle

    init(host: any PathHost) {
        self.host = host
        super.init()
    }

    func start() {
        advance(to: 0)
    }

    func finish() {
        for child in childCoordinators {
            child.finish()
        }
        childCoordinators.removeAll()
    }

    // MARK: - Chain

    /// Spawns the child coordinator for `index` and lets it push its screen.
    private func advance(to index: Int) {
        guard index < steps.count else {
            return
        }

        let step = steps[index]
        let isLast = index == steps.count - 1

        let child = DemoStepCoordinator(
            host: host,
            index: index,
            title: step.title,
            color: step.color,
            // Last step has no next: its button pops the whole demo back to the
            // settings root instead.
            onNext: isLast
                ? { [weak self] in self?.host.pop(animated: true) }
                : { [weak self] in self?.advance(to: index + 1) },
            nextTitle: isLast ? "Done" : "Next"
        )

        childCoordinators.append(child)
        child.start()
    }
}

/// One step of the demo: owns exactly one colored screen and pushes it onto the
/// shared path. Knows nothing but the `PathHost` it was handed.
@MainActor
final class DemoStepCoordinator: NSObject, Coordinator {

    /// This step's single destination. `index` keeps it unique within the path
    /// (the router forbids duplicate destinations).
    struct Destination: Hashable {
        let index: Int
    }

    // MARK: - Coordinator

    var childCoordinators: [any Coordinator] = []
    lazy var rootViewController: UIViewController = UIViewController()

    // MARK: - Private properties

    private unowned let host: any PathHost
    private let index: Int
    private let title: String
    private let color: Color
    private let onNext: () -> Void
    private let nextTitle: String

    private var screenBuilderToken: ScreenBuilderToken?

    private var destination: Destination {
        Destination(index: index)
    }

    // MARK: - Lifecycle

    init(
        host: any PathHost,
        index: Int,
        title: String,
        color: Color,
        onNext: @escaping () -> Void,
        nextTitle: String
    ) {
        self.host = host
        self.index = index
        self.title = title
        self.color = color
        self.onNext = onNext
        self.nextTitle = nextTitle
        super.init()
    }

    func start() {
        screenBuilderToken = host.registerScreenBuilder { [weak self] anyDestination in
            guard
                let self,
                let anyDestination = anyDestination as? Destination,
                anyDestination == destination
            else {
                return nil
            }
            return makeScreen()
        }

        host.push(destination, animated: true)
    }

    func finish() {
        if let screenBuilderToken {
            host.removeScreenBuilder(screenBuilderToken)
        }
        screenBuilderToken = nil

        for child in childCoordinators {
            child.finish()
        }
        childCoordinators.removeAll()
    }

    private func makeScreen() -> UIViewController {
        UIHostingController(
            rootView: DemoStepView(title: title, color: color, nextTitle: nextTitle, onNext: onNext)
        )
    }
}

// MARK: - Screen

private struct DemoStepView: View {
    let title: String
    let color: Color
    let nextTitle: String
    let onNext: () -> Void

    var body: some View {
        ZStack {
            color.opacity(0.25).ignoresSafeArea()

            Button(nextTitle, action: onNext)
                .font(.title2.bold())
                .buttonStyle(.borderedProminent)
                .tint(color)
        }
        .navigationTitle(title)
    }
}
