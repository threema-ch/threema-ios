import Foundation
import ThreemaEssentials
import XCTest

@testable import GroupCalls

final class GroupCallViewModelTests: XCTestCase {
    fileprivate let lock = NSLock()
    fileprivate var navigationContentUpdates = [GroupCallNavigationBarContentUpdate]()
    fileprivate var navigationContentUpdateExpectation: XCTestExpectation?

    fileprivate var closed = false
    fileprivate lazy var creatorIdentity = ThreemaIdentity("ECHOECHO")
    fileprivate lazy var groupIdentity = GroupIdentity(id: Data(repeating: 0x00, count: 8), creator: creatorIdentity)
    fileprivate lazy var localContactModel = ContactModel(identity: creatorIdentity, nickname: "ECHOECHO")
    fileprivate lazy var groupModel = GroupCallThreemaGroupModel(groupIdentity: groupIdentity, groupName: "TESTGROUP")
    fileprivate lazy var sfuBaseURL = URL(string: "sfu.threema.test")!

    /// A `connected` event is handled by the view model and updates the navigation bar
    func testConnectedEventUpdatesNavigationBar() async throws {
        let dependencies = MockDependencies().create()
        let groupCallActor = try GroupCallActor(
            localContactModel: localContactModel,
            groupModel: groupModel,
            sfuBaseURL: sfuBaseURL,
            gck: Data(repeating: 0x01, count: 32),
            dependencies: dependencies
        )

        // We use the view model of the actor. Creating a second one is not allowed, see the `didSet` of `viewModel`.
        let viewModel = await groupCallActor.viewModel
        viewModel.setViewDelegate(self)

        let expectation = XCTestExpectation(description: "Navigation content was updated")
        lock.withLock {
            navigationContentUpdateExpectation = expectation
        }

        await groupCallActor.uiContinuation.yield(.connected)

        await fulfillment(of: [expectation], timeout: 10)

        let lastUpdate = try XCTUnwrap(lock.withLock { navigationContentUpdates.last })
        XCTAssertEqual(lastUpdate.title, "group_call_navbar_state_connected")
    }
}

// MARK: - GroupCallViewModelDelegate

extension GroupCallViewModelTests: GroupCallViewModelDelegate {
    func showRecordAudioPermissionAlert() { }
    
    func showRecordVideoPermissionAlert() { }
    
    func updateCollectionViewLayout() { }
    
    func dismissGroupCallView(animated: Bool) async {
        closed = true
    }

    func updateNavigationContent(_ contentUpdate: GroupCalls.GroupCallNavigationBarContentUpdate) async {
        let expectation = lock.withLock {
            navigationContentUpdates.append(contentUpdate)
            return navigationContentUpdateExpectation
        }

        expectation?.fulfill()
    }
}
