import Foundation
import ThreemaEssentials
import XCTest
@testable import GroupCalls
@testable import ThreemaProtocols

/// Tests for the media key (PCMK) handling of the local participant.
final class MediaKeysTests: XCTestCase {

    fileprivate lazy var localIdentity = ThreemaIdentity("ECHOECHO")
    fileprivate lazy var localContactModel = ContactModel(identity: localIdentity, nickname: "ECHOECHO")

    /// **Protocol Step: Join/Leave of Other Participants (Leave 4.2)** The epoch is increased for every participant
    /// that leaves and wraps back to 0 when it would become 256, i.e. 255 is a valid epoch.
    @GlobalGroupCallActor
    func testEpochWrapsBackToZeroAfter255() async throws {
        let dependencies = MockDependencies().create()

        let localParticipant = try LocalParticipant(
            participantID: ParticipantID(id: 0),
            localContactModel: localContactModel,
            dependencies: dependencies
        )

        XCTAssertEqual(localParticipant.protocolMediaKeys.epoch, 0)

        // Every participant that leaves increases the epoch by one
        for expectedEpoch in 1...255 {
            try localParticipant.replaceAndApplyNewMediaKeys()

            let pendingMediaKeys = try XCTUnwrap(localParticipant.pendingProtocolMediaKeys)
            XCTAssertEqual(pendingMediaKeys.epoch, UInt32(expectedEpoch))
            XCTAssertEqual(pendingMediaKeys.ratchetCounter, 0)

            _ = try localParticipant.switchCurrentForPendingKeys()
        }

        XCTAssertEqual(localParticipant.protocolMediaKeys.epoch, 255)

        // The next epoch would be 256 and thus wraps back to 0
        try localParticipant.replaceAndApplyNewMediaKeys()

        let wrappedMediaKeys = try XCTUnwrap(localParticipant.pendingProtocolMediaKeys)
        XCTAssertEqual(wrappedMediaKeys.epoch, 0)
    }

    /// **Protocol Step: Join/Leave of Other Participants (Join 2.)** The ratchet may be advanced 255 times, advancing
    /// it once more aborts the call with an error condition.
    @GlobalGroupCallActor
    func testRatchetCounterIsCappedAt255() async throws {
        let dependencies = MockDependencies().create()

        let localParticipant = try LocalParticipant(
            participantID: ParticipantID(id: 0),
            localContactModel: localContactModel,
            dependencies: dependencies
        )

        for expectedRatchetCounter in 1...255 {
            try localParticipant.ratchetMediaKeys()
            XCTAssertEqual(localParticipant.protocolMediaKeys.ratchetCounter, UInt32(expectedRatchetCounter))
        }

        do {
            try localParticipant.ratchetMediaKeys()
            XCTFail("Expected the ratchet to be capped at 255")
        }
        catch {
            // Expected: the call has to be aborted with an error condition
        }
    }
}
