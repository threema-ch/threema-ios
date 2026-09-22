import Foundation
import ThreemaEssentials
import XCTest
@testable import GroupCalls
@testable import ThreemaProtocols

/// Characterization tests for the participant handshake state machine.
///
/// These pin behavior that must not change: the transitions out of `await-np-hello` and `await-ep-hello` into
/// `await-auth`, and the check that a received `pck`/`pcck` does not reflect our local one.
final class PendingRemoteParticipantTests: XCTestCase {

    fileprivate lazy var localIdentity = ThreemaIdentity("ECHOECHO")
    fileprivate lazy var localContactModel = ContactModel(identity: localIdentity, nickname: "ECHOECHO")
    fileprivate lazy var remoteIdentity = ThreemaIdentity("OCHEOCHE")
    fileprivate lazy var groupIdentity = GroupIdentity(
        id: Data(repeating: 0x00, count: 8),
        creator: localIdentity
    )
    fileprivate lazy var sfuBaseURL = URL(string: "sfu.threema.test")!

    // The crypto mock returns `Data(repeating: 0x01, count: 32)` for random bytes, thus our local PCCK consists of
    // 0x01 only and the remote values have to differ from it.
    fileprivate let remotePCK = Data(repeating: 0x02, count: 32)
    fileprivate let remotePCCK = Data(repeating: 0x03, count: 32)
    fileprivate let pcckOfCryptoMock = Data(repeating: 0x01, count: 32)

    // MARK: - Tests

    /// **Protocol Step: Initial handshake message. (Receiving regular 3.)** A `Hello` from a newly joined participant
    /// is answered with a `Hello` immediately followed by an `Auth`.
    @GlobalGroupCallActor
    func testNewParticipantHelloIsAnsweredWithHelloAndAuth() async throws {
        let dependencies = MockDependencies().create()
        let crypto = try makeGroupCallBaseState(dependencies: dependencies)
        let local = try makeLocalParticipant(dependencies: dependencies)

        let participant = try PendingRemoteParticipant(
            participantID: ParticipantID(id: 1),
            dependencies: dependencies,
            groupCallMessageCrypto: crypto,
            isExistingParticipant: false
        )

        let envelope = try makeHelloEnvelope(pck: remotePCK, pcck: remotePCCK, crypto: crypto)

        let action = try participant.handle(message: envelope, groupID: groupIdentity, localParticipant: local)

        guard case let .epHelloAndAuth(handledParticipant, (hello, auth)) = action else {
            XCTFail("Expected `epHelloAndAuth` but got \(action)")
            return
        }

        XCTAssertEqual(handledParticipant.participantID, participant.participantID)
        XCTAssertGreaterThan(hello.count, 0)
        XCTAssertGreaterThan(auth.count, 0)
        XCTAssertEqual(participant.threemaIdentity, remoteIdentity)
        XCTAssertEqual(participant.nickname, remoteIdentity.rawValue)
    }

    /// **Protocol Step: Initial handshake message. (Receiving regular 4.2.)** A `Hello` from an existing participant
    /// is answered with an `Auth` only.
    @GlobalGroupCallActor
    func testExistingParticipantHelloIsAnsweredWithAuth() async throws {
        let dependencies = MockDependencies().create()
        let crypto = try makeGroupCallBaseState(dependencies: dependencies)
        let local = try makeLocalParticipant(dependencies: dependencies)

        let participant = try PendingRemoteParticipant(
            participantID: ParticipantID(id: 1),
            dependencies: dependencies,
            groupCallMessageCrypto: crypto,
            isExistingParticipant: true
        )

        let envelope = try makeHelloEnvelope(pck: remotePCK, pcck: remotePCCK, crypto: crypto)

        let action = try participant.handle(message: envelope, groupID: groupIdentity, localParticipant: local)

        guard case let .sendAuth(handledParticipant, auth) = action else {
            XCTFail("Expected `sendAuth` but got \(action)")
            return
        }

        XCTAssertEqual(handledParticipant.participantID, participant.participantID)
        XCTAssertGreaterThan(auth.count, 0)
    }

    /// **Protocol Step: Initial handshake message. (Receiving regular 4.1.)** If the received `pcck` reflects our local
    /// PCCK the message is rejected.
    @GlobalGroupCallActor
    func testExistingParticipantHelloWithReflectedPCCKIsRejected() async throws {
        let dependencies = MockDependencies().create()
        let crypto = try makeGroupCallBaseState(dependencies: dependencies)
        let local = try makeLocalParticipant(dependencies: dependencies)

        let participant = try PendingRemoteParticipant(
            participantID: ParticipantID(id: 1),
            dependencies: dependencies,
            groupCallMessageCrypto: crypto,
            isExistingParticipant: true
        )

        let envelope = try makeHelloEnvelope(pck: remotePCK, pcck: pcckOfCryptoMock, crypto: crypto)

        do {
            _ = try participant.handle(message: envelope, groupID: groupIdentity, localParticipant: local)
            XCTFail("Expected the handshake to reject a reflected PCCK")
        }
        catch let error as GroupCallError {
            guard case .badMessage = error else {
                XCTFail("Expected `badMessage` but got \(error)")
                return
            }
        }
    }

    /// A second `Hello` is not accepted, i.e. the handshake state moved on to `await-auth` after the first one.
    @GlobalGroupCallActor
    func testHelloIsNotAcceptedTwice() async throws {
        let dependencies = MockDependencies().create()
        let crypto = try makeGroupCallBaseState(dependencies: dependencies)
        let local = try makeLocalParticipant(dependencies: dependencies)

        let participant = try PendingRemoteParticipant(
            participantID: ParticipantID(id: 1),
            dependencies: dependencies,
            groupCallMessageCrypto: crypto,
            isExistingParticipant: false
        )

        let envelope = try makeHelloEnvelope(pck: remotePCK, pcck: remotePCCK, crypto: crypto)

        _ = try participant.handle(message: envelope, groupID: groupIdentity, localParticipant: local)

        // The participant now awaits an `Auth`, thus the very same `Hello` must not be handled as a `Hello` again
        do {
            _ = try participant.handle(message: envelope, groupID: groupIdentity, localParticipant: local)
            XCTFail("Expected the handshake to reject a second `Hello`")
        }
        catch {
            // Expected: the message is not a valid `Auth`
        }
    }

    // MARK: - Private Helper Functions

    @GlobalGroupCallActor
    fileprivate func makeGroupCallBaseState(dependencies: Dependencies) throws -> GroupCallBaseState {
        try TestDataProvider.groupCallBaseState(
            group: GroupCallThreemaGroupModel(groupIdentity: groupIdentity, groupName: "TESTGROUP"),
            dependencies: dependencies,
            protocolVersion: 1,
            sfuBaseURL: sfuBaseURL
        )
    }

    @GlobalGroupCallActor
    fileprivate func makeLocalParticipant(dependencies: Dependencies) throws -> LocalParticipant {
        try LocalParticipant(
            participantID: ParticipantID(id: 0),
            localContactModel: localContactModel,
            dependencies: dependencies
        )
    }

    @GlobalGroupCallActor
    fileprivate func makeHelloEnvelope(
        identity: String = "OCHEOCHE",
        nickname: String = "OCHEOCHE",
        pck: Data,
        pcck: Data,
        crypto: GroupCallBaseState,
        sender: UInt32 = 1
    ) throws -> GroupCall_ParticipantToParticipant.OuterEnvelope {
        var helloMessage = GroupCall_ParticipantToParticipant.Handshake.Hello()
        helloMessage.identity = identity
        helloMessage.nickname = nickname
        helloMessage.pck = pck
        helloMessage.pcck = pcck

        let nonce = Data(repeating: 0x03, count: 24)

        var handshakeHello = GroupCall_ParticipantToParticipant.Handshake.HelloEnvelope()
        handshakeHello.hello = helloMessage
        handshakeHello.padding = nonce

        let serialized = try handshakeHello.ownSerializedData()
        let encrypted = try XCTUnwrap(crypto.symmetricEncryptByGCHK(serialized, nonce: nonce))

        var data = nonce
        data.append(encrypted)

        var envelope = GroupCall_ParticipantToParticipant.OuterEnvelope()
        envelope.encryptedData = data
        envelope.receiver = 0
        envelope.sender = sender

        return envelope
    }
}
