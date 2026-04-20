import XCTest
@testable import Threema
@testable import ThreemaFramework

final class VoIPCallServiceTests: XCTestCase {

    private var testDatabase: TestDatabase!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
    }

    func testPeerConnectionClientDidChangeConnectionState() throws {
        let voIPCallPeerConnectionClientMock = VoIPCallPeerConnectionClientMock()

        let callID = VoIPCallID.generate()
        let voIPCallService = VoIPCallService(
            callPartnerIdentity: "TESTERID",
            callID: callID,
            delegate: nil,
            callKitManager: VoIPCallKitManager(),
            businessInjector: BusinessInjectorMock(
                entityManager: testDatabase.entityManager
            ),
            peerConnectionClient: voIPCallPeerConnectionClientMock
        )
        voIPCallPeerConnectionClientMock.delegate = voIPCallService

        XCTAssertEqual(voIPCallService.currentState(), .idle)

        voIPCallPeerConnectionClientMock.delegate?.peerConnectionClient(
            voIPCallPeerConnectionClientMock,
            didChangeConnectionState: .connecting
        )

        XCTAssertEqual(voIPCallService.currentState(), .initializing)
    }
}
