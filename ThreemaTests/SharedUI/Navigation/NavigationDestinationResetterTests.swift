import Testing
import UIKit
@testable import Threema

@Suite("NavigationDestinationResetter Tests")
@MainActor
struct NavigationDestinationResetterTests {
    
    @Test("Does not reset destination when navigating to non-root view controller")
    func doesNotResetWhenNotShowingRootViewController() {
        let (sut, navigationController, _, destinationHolder) = makeSUT(
            splitViewController: makeCollapsedSplitViewController()
        )
        
        let otherViewController = UIViewController()
        
        sut.navigationController(
            navigationController,
            willShow: otherViewController,
            animated: false
        )
        
        #expect(destinationHolder.resetCurrentDestinationCallCount == 0)
    }
    
    @Test("Does not reset destination when split view controller is not collapsed")
    func doesNotResetWhenSplitViewControllerIsNotCollapsed() {
        let rootViewController = UIViewController()
        let splitViewController = makeExpandedSplitViewController()
        let (sut, navigationController, _, destinationHolder) = makeSUT(
            rootViewController: rootViewController,
            splitViewController: splitViewController
        )
        
        sut.navigationController(
            navigationController,
            didShow: rootViewController,
            animated: false
        )
        
        #expect(destinationHolder.resetCurrentDestinationCallCount == 0)
    }
    
    @Test("Does not reset destination when split view controller is nil")
    func doesNotResetWhenSplitViewControllerIsNil() {
        let rootViewController = UIViewController()
        let (sut, navigationController, _, destinationHolder) = makeSUT(
            rootViewController: rootViewController,
            splitViewController: nil
        )
        
        sut.navigationController(
            navigationController,
            didShow: rootViewController,
            animated: false
        )
        
        #expect(destinationHolder.resetCurrentDestinationCallCount == 0)
    }
    
    @Test("Resets destination when navigating back to root and split view is collapsed")
    func resetsDestinationWhenNavigatingBackToRootInCollapsedSplitView() {
        let rootViewController = UIViewController()
        let splitViewController = makeCollapsedSplitViewController()
        let (sut, navigationController, _, destinationHolder) = makeSUT(
            rootViewController: rootViewController,
            splitViewController: splitViewController
        )
        
        sut.navigationController(
            navigationController,
            willShow: rootViewController,
            animated: false
        )
        
        #expect(destinationHolder.resetCurrentDestinationCallCount == 1)
    }
    
    @Test("Resets destination when navigating back to root")
    func resetsDestinationWhenNavigatingBackToRootWithAnimation() {
        let rootViewController = UIViewController()
        let splitViewController = makeCollapsedSplitViewController()
        let (sut, navigationController, _, destinationHolder) = makeSUT(
            rootViewController: rootViewController,
            splitViewController: splitViewController
        )
        
        sut.navigationController(
            navigationController,
            willShow: rootViewController,
            animated: true
        )
        
        #expect(destinationHolder.resetCurrentDestinationCallCount == 1)
    }
    
    @Test("Resets destination multiple times on multiple navigations back to root")
    func resetsDestinationMultipleTimesOnMultipleNavigations() {
        let rootViewController = UIViewController()
        let splitViewController = makeCollapsedSplitViewController()
        let (sut, navigationController, _, destinationHolder) = makeSUT(
            rootViewController: rootViewController,
            splitViewController: splitViewController
        )
        
        sut.navigationController(
            navigationController,
            willShow: rootViewController,
            animated: false
        )
        
        sut.navigationController(
            navigationController,
            willShow: rootViewController,
            animated: false
        )
        
        sut.navigationController(
            navigationController,
            willShow: rootViewController,
            animated: false
        )
        
        #expect(destinationHolder.resetCurrentDestinationCallCount == 3)
    }
    
    @Test("Does not reset when both conditions fail")
    func doesNotResetWhenBothConditionsFail() {
        let rootViewController = UIViewController()
        let splitViewController = makeExpandedSplitViewController()
        let (sut, navigationController, _, destinationHolder) = makeSUT(
            rootViewController: rootViewController,
            splitViewController: splitViewController
        )
        
        let otherViewController = UIViewController()
        
        sut.navigationController(
            navigationController,
            didShow: otherViewController,
            animated: false
        )
        
        #expect(destinationHolder.resetCurrentDestinationCallCount == 0)
    }
    
    // MARK: - Factory
    
    private func makeSUT(
        rootViewController: UIViewController? = nil,
        splitViewController: UISplitViewController? = nil,
        destinationHolder: CurrentDestinationHolderSpy = CurrentDestinationHolderSpy()
    ) -> (
        sut: NavigationDestinationResetter,
        navigationController: UINavigationController,
        rootViewController: UIViewController,
        destinationHolder: CurrentDestinationHolderSpy
    ) {
        let rootVC = rootViewController ?? UIViewController()
        let navigationController = UINavigationController(rootViewController: rootVC)
        
        let sut = NavigationDestinationResetter(
            rootViewController: rootVC,
            splitViewController: splitViewController,
            destinationHolder: destinationHolder
        )
        
        navigationController.delegate = sut
        navigationController.loadViewIfNeeded()
        
        return (sut, navigationController, rootVC, destinationHolder)
    }
    
    private func makeCollapsedSplitViewController() -> UISplitViewController {
        CollapsedSplitViewControllerStub()
    }
    
    private func makeExpandedSplitViewController() -> UISplitViewController {
        ExpandedSplitViewControllerStub()
    }
    
    // MARK: - Test Doubles
    
    final class CurrentDestinationHolderSpy: CurrentDestinationHolderProtocol {
        typealias CurrentDestination = String
        
        var currentDestination: String?
        private(set) var resetCurrentDestinationCallCount = 0
        
        func resetCurrentDestination() {
            resetCurrentDestinationCallCount += 1
        }
    }
    
    private final class CollapsedSplitViewControllerStub: UISplitViewController {
        override var isCollapsed: Bool { true }
    }
    
    private final class ExpandedSplitViewControllerStub: UISplitViewController {
        override var isCollapsed: Bool { false }
    }
}
