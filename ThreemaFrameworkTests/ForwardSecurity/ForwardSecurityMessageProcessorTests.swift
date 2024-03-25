//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import ThreemaEssentials
import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

class ForwardSecurityMessageProcessorTests: XCTestCase {
    static let numRandomRuns = 20
    
    static let aliceMessage1 = "Hello Bob!"
    static let aliceMessage2 = "Now we're in 4DH mode!"
    static let aliceMessage3 = "This message will never arrive."
    static let aliceMessage4 = "But this one will."
    static let aliceMessage5 = "Why did you lose your data, Bob?"
    static let aliceMessage6 = "Just making sure I can still reach you in 4DH mode."
    static let aliceMessage7 = "Looks good."
    static let aliceGroupMessage1 = "Hi Bob. This is a group message."
    static let bobMessage1 = "Hello Alice, glad to talk to you in 4DH mode!"
    static let bobMessage2 = "Hello Alice, I haven't heard from you yet!"
    static let bobMessage3 = "Let's see whose session we will use..."
    
    private let aliceIdentity = ThreemaIdentity("AAAAAAAA")
    
    private var aliceContext: UserContext!
    private var bobContext: UserContext!
    
    private lazy var groupIdentity = GroupIdentity(id: MockData.generateGroupID(), creator: aliceIdentity)
    
    override func setUp() {
        continueAfterFailure = false
        DDLog.add(DDOSLogger.sharedInstance)
    }
    
    func testNegotiationAnd2DH() async throws {
        // Start the negotiation on Alice's side, up to the point where the Init and Message are
        // on the way to Bob, but have not been received by him yet
        try startNegotiationAlice()
        
        // Let Bob process all the messages that he has received from Alice.
        // The decapsulated message should be the text message from Alice.
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage1,
            expectedMode: .twoDH
        )
        
        // Both should have the session now
        guard var alicesInitiatorSession = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: bobContext.identityStore.identity
        ) else {
            XCTFail()
            return
        }
        XCTAssertNotNil(alicesInitiatorSession)
        
        guard var bobsResponderSession = try bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: aliceContext.identityStore.identity
        ) else {
            XCTFail()
            return
        }
        
        // At this point, Bob should have enqueued one FS message: Accept
        XCTAssertEqual(bobContext!.dummySender.sentAbstractMessagesQueue.count, 1)
        
        // Let Alice process the Accept message that she has received from Bob
        let alicesReceivedMessages = try await processReceivedMessages(
            senderContext: bobContext,
            recipientContext: aliceContext
        )
        
        // Bob has not sent any actual message to Alice
        XCTAssertEqual(alicesReceivedMessages.count, 0)
        
        // Alice has already discarded her 2DH ratchets.
        XCTAssertEqual(try alicesInitiatorSession.state, .RL44)
        
        // At this point, Alice and Bob should have one mutual 4DH session. Alice has already
        // discarded her 2DH ratchets.
        alicesInitiatorSession = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        )!
        XCTAssertNil(alicesInitiatorSession.myRatchet2DH)
        XCTAssertNil(alicesInitiatorSession.peerRatchet2DH)
        XCTAssertNotNil(alicesInitiatorSession.myRatchet4DH)
        XCTAssertNotNil(alicesInitiatorSession.peerRatchet4DH)
        
        // Bob has not received a 4DH message yet, so he still has a 2DH peer ratchet
        XCTAssertEqual(try bobsResponderSession.state, .R24)
        
        // Bob has not received a 4DH message yet, so he still has a 2DH peer ratchet
        bobsResponderSession = try bobContext.dhSessionStore.exactDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity,
            sessionID: alicesInitiatorSession.id
        )!
        XCTAssertNil(bobsResponderSession.myRatchet2DH)
        XCTAssertNotNil(bobsResponderSession.peerRatchet2DH)
        XCTAssertNotNil(bobsResponderSession.myRatchet4DH)
        XCTAssertNotNil(bobsResponderSession.peerRatchet4DH)
        
        // The 2DH peer ratchet counter should be 2 on Bob's side to match the single 2DH message that
        // he has received (counter is incremented automatically after reception), and the 4DH ratchet
        // counters should be 1 on both sides as no 4DH messages have been exchanged yet.
        XCTAssertEqual(bobsResponderSession.peerRatchet2DH!.counter, 2)
        XCTAssertEqual(alicesInitiatorSession.myRatchet4DH!.counter, 1)
        XCTAssertEqual(alicesInitiatorSession.peerRatchet4DH!.counter, 1)
        XCTAssertEqual(bobsResponderSession.myRatchet4DH!.counter, 1)
        XCTAssertEqual(bobsResponderSession.peerRatchet4DH!.counter, 1)
    }
    
    func test4DH() async throws {
        try await testNegotiationAnd2DH()
        
        // Alice now sends Bob another message, this time in 4DH mode
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage2, senderContext: aliceContext)
        
        // Let Bob process all the messages that he has received from Alice.
        // The decapsulated message should be the text message from Alice.
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage2,
            expectedMode: .fourDH
        )
        
        // At this point, Bob should not have enqueued any further messages
        XCTAssertEqual(bobContext.dummySender.sentAbstractMessagesQueue.count, 0)
        
        // Bob should have discarded his 2DH peer ratchet now
        let bobsResponderSession = try bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity
        )!
        XCTAssertEqual(try bobsResponderSession.state, .RL44)
        XCTAssertNil(bobsResponderSession.peerRatchet2DH)
        
        // Bob now sends Alice a message in the new session
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.bobMessage1, senderContext: bobContext)
        
        // Let Alice process the messages that she has received from Bob.
        // The decapsulated message should be the text message from Bob.
        try await receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage1,
            expectedMode: .fourDH
        )
    }
    
    func test4DHGroupMessage() async throws {
        try XCTSkipIf(!ThreemaEnvironment.fsEnableV12, "This only works with PFS 1.2 and up")

        try await test4DH()
        
        // Alice sends a group message to Bob
        try sendGroupTextMessage(
            message: ForwardSecurityMessageProcessorTests.aliceGroupMessage1,
            senderContext: aliceContext,
            groupIdentity: groupIdentity
        )
        
        // Bob should receive the message
        try await receiveAndAssertSingleGroupMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceGroupMessage1,
            expectedMode: .fourDH,
            expectedGroupIdentity: groupIdentity
        )
        
        // At this point, Bob should not have enqueued any further messages
        XCTAssertEqual(bobContext.dummySender.sentAbstractMessagesQueue.count, 0)
    }
    
    func testUnsupportedFSMessage() async throws {
        try await test4DH()
        
        // Set last FS/session message sent to 23h ago
        let session = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        ))
        session.lastMessageSent = Date(timeIntervalSinceNow: -(60 * 60 * 23))
        try aliceContext.dhSessionStore.updateNewSessionCommitLastMessageSentDateAndVersions(session: session)
        
        // Create a message that doesn't support FS and send it
        try sendUnsupportedFSMessage(senderContext: aliceContext)
        
        // The message itself should be sent without FS (empty messages are only prepended when the last FS message was
        // sent more than 24h ago)
        XCTAssertEqual(aliceContext.dummySender.sentAbstractMessagesQueue.count, 1)
        
        // Validate unsupported message
        let unsupportedMessage = aliceContext.dummySender.sentAbstractMessagesQueue.removeFirst()
        XCTAssertFalse(unsupportedMessage is ForwardSecurityEnvelopeMessage)
        XCTAssertEqual(unsupportedMessage.minimumRequiredForwardSecurityVersion(), .unspecified)
        
        // Now all messages should be processed
        XCTAssertEqual(aliceContext.dummySender.sentAbstractMessagesQueue.count, 0)
    }
    
    func testEmptyMessage() async throws {
        try await test4DH()
        
        // Set last FS/session message sent date to more than 24h ago
        let session = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        ))
        session.lastMessageSent = Date(timeIntervalSinceNow: -(60 * 60 * 25))
        try aliceContext.dhSessionStore.updateNewSessionCommitLastMessageSentDateAndVersions(session: session)
        
        // Create a message that doesn't support FS and send it
        try sendUnsupportedFSMessage(senderContext: aliceContext)
        
        // An empty message with FS and the message itself should be sent
        XCTAssertEqual(aliceContext.dummySender.sentAbstractMessagesQueue.count, 2)
        
        // Validate empty message
        
        let encapsulatedEmptyMessage = aliceContext.dummySender.sentAbstractMessagesQueue.removeFirst()
        let (emptyMessage, fsMessageInfo) = try await bobContext.fsmp.processEnvelopeMessage(
            sender: bobContext.peerContact,
            envelopeMessage: encapsulatedEmptyMessage as! ForwardSecurityEnvelopeMessage
        )
        if let fsMessageInfo {
            _ = fsMessageInfo.updateVersionsIfNeeded()
            try bobContext.dhSessionStore.storeDHSession(session: fsMessageInfo.session)
        }
        
        XCTAssertTrue(emptyMessage is BoxEmptyMessage)
        XCTAssertNotNil(emptyMessage)
        
        // Validate unsupported message
        let unsupportedMessage = aliceContext.dummySender.sentAbstractMessagesQueue.removeFirst()
        XCTAssertFalse(unsupportedMessage is ForwardSecurityEnvelopeMessage)
        XCTAssertEqual(unsupportedMessage.minimumRequiredForwardSecurityVersion(), .unspecified)
        
        // Now all messages should be processed
        XCTAssertEqual(aliceContext.dummySender.sentAbstractMessagesQueue.count, 0)
    }
    
    func testMissingMessage() async throws {
        try await test4DH()
        
        // Alice now sends Bob another message, but it never arrives
        let encapResult = try makeEncapTextMessage(
            text: ForwardSecurityMessageProcessorTests.aliceMessage3,
            senderContext: aliceContext
        )
        
        // Drop this message.
        
        // Alice now sends Bob another message, which arrives and should be decodable
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage4, senderContext: aliceContext)
        
        // Let Bob process all the messages that he has received from Alice.
        // The decapsulated message should be the text message from Alice.
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage4,
            expectedMode: .fourDH
        )
        
        // At this point, Bob should not have enqueued any further messages
        XCTAssertEqual(bobContext.dummySender.sentAbstractMessagesQueue.count, 0)
    }
    
    func testDataLoss() async throws {
        // Repeat the tests several times, as random session IDs are involved
        for _ in 1...ForwardSecurityMessageProcessorTests.numRandomRuns {
            try await doTestDataLoss1()
            try await doTestDataLoss2()
        }
    }
    
    private func setupDataLoss() async throws {
        try await test4DH()
        
        // Check that Bob has a responder DH session that matches Alice's initiator session.
        let alicesSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        ))
        XCTAssertNotNil(try bobContext.dhSessionStore.exactDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity,
            sessionID: alicesSession.id
        ))
        
        // Now Bob loses his session data
        try bobContext.dhSessionStore.deleteDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity,
            sessionID: alicesSession.id
        )
    }
    
    private func doTestDataLoss1() async throws {
        // Data loss scenario 1: Bob loses his data, but does not send any messages until Alice
        // sends her first message after the data loss. This message gets rejected by Bob, and eventually
        // both agree on a new 4DH session.
        try await setupDataLoss()
        
        // Set up expectation that the failure listener is invoked on Alice's side
        // let rejectListenerExpectation = expectation(description: "rejectReceived")
        // let listener = RejectStatusListener(expectation: rejectListenerExpectation)
        // aliceContext.fsmp.addListener(listener: listener)
        
        let alicesBestSession = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        )!
        
        // Alice sends another message, which Bob can't decrypt and should trigger a Reject
        let encapMessage = try sendTextMessage(
            message: ForwardSecurityMessageProcessorTests.aliceMessage5,
            senderContext: aliceContext
        )
        
        // Let Bob process all the messages that he has received from Alice.
        let bobsReceivedMessages = try await processReceivedMessages(
            senderContext: aliceContext,
            recipientContext: bobContext
        )
        
        // There should be no decrypted messages
        XCTAssertEqual(bobsReceivedMessages.count, 0)
        
        // Bob should have enqueued one FS message (a reject) to Alice.
        XCTAssertEqual(bobContext.dummySender.sentAbstractMessagesQueue.count, 1)
        
        // Let Alice process the reject message that she has received from Bob.
        let alicesReceivedMessages = try await processReceivedMessages(
            senderContext: bobContext,
            recipientContext: aliceContext
        )
        
        // There should be no decrypted messages
        XCTAssertEqual(alicesReceivedMessages.count, 0)
        
        // Alice and Bob should have deleted their mutual DH sessions.
        XCTAssertNil(try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        ))
        XCTAssertNil(try bobContext.dhSessionStore.exactDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity,
            sessionID: alicesBestSession.id
        ))
        
        // Check that the failure listener has been informed on Alice's side.
        // await fulfillment(of: [rejectListenerExpectation], timeout: 5)
        // XCTAssertEqual(listener.rejectedMessageID, encapMessage.messageID)
    }
    
    private func doTestDataLoss2() async throws {
        // Data loss scenario 2: Bob loses his data and sends a message in a new session before
        // Alice gets a chance to send one. Alice should take the Init from Bob as a hint that he
        // has lost his session data, and she should discard the existing (4DH) session.
        try await setupDataLoss()
        
        // Bob sends Alice a message, and since he doesn't have a session anymore, he starts a new one
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.bobMessage2, senderContext: bobContext)
        
        let bobsBestSession = try XCTUnwrap(bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity
        ))
        XCTAssertEqual(try bobsBestSession.state, .L20)
        
        // Let Alice process all the messages that she has received from Bob.
        try await receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage2,
            expectedMode: .twoDH
        )
        
        // Alice should have enqueued an Accept for the new session to Bob
        let alicesBestSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        ))
        XCTAssertEqual(aliceContext.dummySender.sentAbstractMessagesQueue.count, 1)
        XCTAssertEqual(try alicesBestSession.state, .R24)
        
        // Alice now sends a message to Bob, which should be in 4DH mode
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage6, senderContext: aliceContext)
        XCTAssertEqual(try alicesBestSession.state, .R24)
        
        // Let Bob process the messages that he has received from Alice.
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage6,
            expectedMode: .fourDH
        )
        XCTAssertEqual(try bobsBestSession.state, .RL44)
        
        XCTAssertEqual(alicesBestSession.id, bobsBestSession.id)
    }
    
    func testDowngrade() async throws {
        try await test4DH()
        
        // Bob has received a 4DH message from Alice, and thus both parties should
        // not have a 2DH session anymore
        let alicesSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        ))
        let bobsSession = try XCTUnwrap(bobContext.dhSessionStore.exactDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity,
            sessionID: alicesSession.id
        ))
        XCTAssertNil(alicesSession.myRatchet2DH)
        XCTAssertNil(alicesSession.peerRatchet2DH)
        XCTAssertEqual(try alicesSession.state, .RL44)
        XCTAssertNil(bobsSession.myRatchet2DH)
        XCTAssertNil(bobsSession.peerRatchet2DH)
        XCTAssertEqual(try bobsSession.state, .RL44)
    }
    
    func testSendFailure() throws {
        makeAliceContext()

        _ = try makeEncapTextMessage(text: "Test", senderContext: aliceContext)

        // Alice should now have a 2DH session with Bob
        let alicesInitiatorSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        ))
        XCTAssertNotNil(alicesInitiatorSession.myRatchet2DH)

        // As the the session was never marked as committed the next try to create a message should generate an `Init`
        // aux message again
        let encapMessages2 = try makeEncapTextMessage(text: "Test", senderContext: aliceContext)
        let auxMessage2 = try XCTUnwrap(encapMessages2.auxMessage)
        XCTAssertTrue(auxMessage2.data is ForwardSecurityDataInit)
    }
    
    func testRaceConditions() async throws {
        // Repeat the tests several times, as random session IDs are involved
        for _ in 1...ForwardSecurityMessageProcessorTests.numRandomRuns {
            try await doTestRaceCondition1()
            try await doTestRaceCondition2()
        }
    }
    
    // TODO: (IOS-3949) Test changed
    func testMinorVersionUpgrade() async throws {
        // Alice supports version 1.0 and 1.1. Bob only supports version 1.0. Later he will upgrade
        // his version to 1.1.

        // Alice starts negotiation with supported version 1.1
        XCTAssertNoThrow(try startNegotiationAlice())
        
        // Bob handles the init while only supporting version 1.0
        
        var range = CspE2eFs_VersionRange()
        range.min = UInt32(CspE2eFs_Version.v10.rawValue)
        range.max = UInt32(CspE2eFs_Version.v10.rawValue)
        
        setSupportedVersionRange(range)
        
        XCTAssertEqual(UInt32(CspE2eFs_Version.v10.rawValue), ThreemaEnvironment.fsVersion.max)
        
        // Note that Bob only processes one message, i.e. the init message. He does not yet process
        // the text message
        try await processOneReceivedMessage(senderContext: aliceContext, recipientContext: bobContext)
        
        // Alice should process the accept message now (while supporting version 1.1)
        range.max = UInt32(CspE2eFs_Version.v11.rawValue)
        
        setSupportedVersionRange(range)
        
        try await processReceivedMessages(senderContext: bobContext, recipientContext: aliceContext)
        
        // Alice should now have initiated a session with negotiated version 1.0
        let aliceSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: bobContext.identityStore.identity
        ))
        XCTAssertEqual(.v10, aliceSession.current4DHVersions?.local)
        XCTAssertEqual(try aliceSession.state, .RL44)
        XCTAssertEqual(aliceSession.current4DHVersions, DHVersions.restored(local: .v10, remote: .v10))
        XCTAssertEqual(
            try! DHSession.supportedVersionWithin(majorVersion: .v10),
            ThreemaEnvironment.fsEnableV12 ? .v12 : .v11
        )
        XCTAssertEqual(
            try! DHSession.supportedVersionWithin(majorVersion: .v10),
            ThreemaEnvironment.fsEnableV12 ? .v12 : .v11
        )
        XCTAssertEqual(aliceSession.outgoingOfferedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
        XCTAssertEqual(aliceSession.outgoingAppliedVersion, .v10)
        XCTAssertEqual(aliceSession.minimumIncomingAppliedVersion, .v10)
        
        // Bob also has initiated a session with negotiated version 1.0
        let bobSession = try XCTUnwrap(bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: aliceContext.identityStore.identity
        ))
        XCTAssertEqual(.v10, bobSession.current4DHVersions?.local)
        XCTAssertEqual(try bobSession.state, .R24)
        XCTAssertEqual(bobSession.current4DHVersions, DHVersions.restored(local: .v10, remote: .v10))
        XCTAssertEqual(bobSession.outgoingOfferedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
        XCTAssertEqual(bobSession.outgoingAppliedVersion, .v10)
        XCTAssertEqual(bobSession.minimumIncomingAppliedVersion, .v10)
        
        // Now Bob processes the text message from Alice. Because this is still a 2DH message, Bob will not update the
        // local/outgoing version to 1.1 yet.
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage1,
            expectedMode: .twoDH
        )
        XCTAssertEqual(try bobSession.state, .R24)
        XCTAssertEqual(bobSession.current4DHVersions, DHVersions.restored(local: .v10, remote: .v10))
        XCTAssertEqual(bobSession.outgoingOfferedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
        XCTAssertEqual(bobSession.outgoingAppliedVersion, .v10)
        XCTAssertEqual(bobSession.minimumIncomingAppliedVersion, .v10)
        
        // Alice sends another text message, this time with 4DH.
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage1, senderContext: aliceContext)
        XCTAssertEqual(try aliceSession.state, .RL44)
        XCTAssertEqual(aliceSession.current4DHVersions, DHVersions.restored(local: .v10, remote: .v10))
        XCTAssertEqual(aliceSession.outgoingOfferedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
        XCTAssertEqual(aliceSession.outgoingAppliedVersion, .v10)
        XCTAssertEqual(aliceSession.minimumIncomingAppliedVersion, .v10)
        
        // This time, Bob will update the local/outgoing version to 1.1.
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage1,
            expectedMode: .fourDH
        )
        XCTAssertEqual(try bobSession.state, .RL44)
        XCTAssertEqual(
            bobSession.current4DHVersions,
            DHVersions.restored(local: ThreemaEnvironment.fsEnableV12 ? .v12 : .v11, remote: .v10)
        )
        XCTAssertEqual(bobSession.outgoingOfferedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
        XCTAssertEqual(bobSession.outgoingAppliedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
        XCTAssertEqual(bobSession.minimumIncomingAppliedVersion, .v10)
    
        // Now Bob sends a message with offered and applied version 1.1.
        XCTAssertNoThrow(try sendTextMessage(
            message: ForwardSecurityMessageProcessorTests.bobMessage1,
            senderContext: bobContext
        ))
        XCTAssertEqual(try bobSession.state, .RL44)
        XCTAssertEqual(
            bobSession.current4DHVersions,
            DHVersions.restored(local: ThreemaEnvironment.fsEnableV12 ? .v12 : .v11, remote: .v10)
        )
        XCTAssertEqual(bobSession.outgoingOfferedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
        XCTAssertEqual(bobSession.outgoingAppliedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
        XCTAssertEqual(bobSession.minimumIncomingAppliedVersion, .v10)
        
        // Alice processes Bob's message (where 1.1 is offered and applied). This updates both Alice's local/outgoing
        // and remote/incoming version to 1.1 from Alice's perspective.
        try await receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage1,
            expectedMode: .fourDH
        )
        XCTAssertEqual(try aliceSession.state, .RL44)
        XCTAssertEqual(
            aliceSession.current4DHVersions,
            DHVersions
                .restored(
                    local: ThreemaEnvironment.fsEnableV12 ? .v12 : .v11,
                    remote: ThreemaEnvironment.fsEnableV12 ? .v12 : .v11
                )
        )
        XCTAssertEqual(aliceSession.outgoingOfferedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
        XCTAssertEqual(aliceSession.outgoingAppliedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
        XCTAssertEqual(aliceSession.minimumIncomingAppliedVersion, ThreemaEnvironment.fsEnableV12 ? .v12 : .v11)
    }
    
    func testRequiredVersionForMessageTypes() async throws {
        // Alice supports version 1.0 and 1.1. Bob only supports version 1.0. Later he will upgrade
        // his version to 1.1.

        // Alice starts negotiation with supported version 1.1
        XCTAssertNoThrow(try startNegotiationAlice())
        
        // Bob handles the init while only supporting version 1.0
        var range = CspE2eFs_VersionRange()
        range.min = UInt32(CspE2eFs_Version.v10.rawValue)
        range.max = UInt32(CspE2eFs_Version.v10.rawValue)
        
        setSupportedVersionRange(range)
        
        XCTAssertEqual(UInt32(CspE2eFs_Version.v10.rawValue), ThreemaEnvironment.fsVersion.max)
        
        // Bob processes the messages now. First he processes the init message, and sends back an
        // accept with support for only v1.0. Then he processes Alice's text message and upgrades
        // to V1.1 (because we did not mock the announced version).
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage1,
            expectedMode: .twoDH
        )
        
        // Alice should process the accept message now (while supporting version 1.1)
        range.max = UInt32(CspE2eFs_Version.v11.rawValue)
        
        setSupportedVersionRange(range)
        
        _ = try await processReceivedMessages(senderContext: bobContext, recipientContext: aliceContext)
        
        // At this point, Alice has a session with negotiated version 1.0, whereas Bob has negotiated version 1.1. This
        // does not change, as long as Alice does not process any message of Bob (which now all would announce version
        // 1.1).
        // Now we check that messages that are not supported in version 1.0 are rejected by the forward security message
        // processor
        
        try assertMessageTypeSupport(BoxVoIPCallOfferMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(BoxVoIPCallRingingMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(BoxVoIPCallAnswerMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(BoxVoIPCallHangupMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(BoxVoIPCallIceCandidatesMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(DeliveryReceiptMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(TypingIndicatorMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(ContactSetPhotoMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(ContactDeletePhotoMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(ContactRequestPhotoMessage(), context: aliceContext, supported: false)
        
        // Check that messages that are currently not supported to send with forward security are rejected
        try assertMessageTypeSupport(GroupCreateMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(GroupFileMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(GroupRequestSyncMessage(), context: aliceContext, supported: false)
        
        // Check that messages that are supported starting with version 1.0 are not rejected initially
        try assertMessageTypeSupport(BoxTextMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxLocationMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxFileMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxBallotCreateMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxBallotVoteMessage(), context: aliceContext, supported: true)
    }
    
    func testInitialNegotiatedVersion() throws {
        makeAliceContext()
        makeBobContext()
        
        // Check that messages that require version 1.1 are rejected
        try assertMessageTypeSupport(BoxVoIPCallOfferMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(BoxVoIPCallRingingMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(BoxVoIPCallAnswerMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(BoxVoIPCallHangupMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(BoxVoIPCallIceCandidatesMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(DeliveryReceiptMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(TypingIndicatorMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(ContactSetPhotoMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(ContactDeletePhotoMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(ContactRequestPhotoMessage(), context: aliceContext, supported: false)
        
        // Check that messages that are currently not supported to send with forward security are rejected
        try assertMessageTypeSupport(GroupCreateMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(GroupFileMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(GroupRequestSyncMessage(), context: aliceContext, supported: false)
        
        // Check that messages that are supported starting with version 1.0 are not rejected initially
        try assertMessageTypeSupport(BoxTextMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxLocationMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxFileMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxBallotCreateMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxBallotVoteMessage(), context: aliceContext, supported: true)
    }
    
    func testMessageSupportOfV12() async throws {
        // Start the negotiation on Alice's side, up to the point where the Init and Message are
        // on the way to Bob, but have not been received by him yet
        try startNegotiationAlice()
        
        // Let Bob process all the messages that he has received from Alice.
        // The decapsulated message should be the text message from Alice.
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage1,
            expectedMode: .twoDH
        )
        
        // Let Alice process the Accept message that she has received from Bob
        _ = try await processReceivedMessages(
            senderContext: bobContext,
            recipientContext: aliceContext
        )
        
        // Alice should have a 4DH session negotiated with 1.2 support now
        let aliceSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: bobContext.identityStore.identity
        ))
        XCTAssertEqual(aliceSession.outgoingAppliedVersion, .v12)
        
        // Check some 1.0 messages
        try assertMessageTypeSupport(BoxTextMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxLocationMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxFileMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxBallotCreateMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxBallotVoteMessage(), context: aliceContext, supported: true)
        
        // Check some 1.1 messages
        try assertMessageTypeSupport(BoxVoIPCallOfferMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxVoIPCallRingingMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxVoIPCallAnswerMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxVoIPCallHangupMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(BoxVoIPCallIceCandidatesMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(DeliveryReceiptMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(TypingIndicatorMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(ContactSetPhotoMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(ContactDeletePhotoMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(ContactRequestPhotoMessage(), context: aliceContext, supported: true)
        
        // Check messages new supported in 1.2 (i.e. group messages)
        try assertMessageTypeSupport(GroupBallotCreateMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupBallotVoteMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupCallStartMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupCreateMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupDeletePhotoMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupDeliveryReceiptMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupFileMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupLeaveMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupLocationMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupRenameMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupRequestSyncMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupSetPhotoMessage(), context: aliceContext, supported: true)
        try assertMessageTypeSupport(GroupTextMessage(), context: aliceContext, supported: true)

        // Check unsupported group legacy messages
        try assertMessageTypeSupport(GroupAudioMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(GroupImageMessage(), context: aliceContext, supported: false)
        try assertMessageTypeSupport(GroupVideoMessage(), context: aliceContext, supported: false)
    }
    
    // TODO: (IOS-3949) Test changed
    func testMinorVersionUpgradeToUnknownVersion() async throws {
        // Alice and Bob support versions 1.x. Bob will later upgrade his version to 1.255.

        // Alice starts negotiation
        XCTAssertNoThrow(try startNegotiationAlice())
        
        // Bob processes the init and the text message of alice
        _ = try await processReceivedMessages(senderContext: aliceContext, recipientContext: bobContext)
        
        // Alice should process the accept message now
        _ = try await processReceivedMessages(senderContext: bobContext, recipientContext: aliceContext)
        
        // Alice should now have initiated a session with the maximum supported version
        let aliceSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: bobContext.identityStore.identity
        ))
        let aliceSession4DHVersions = try XCTUnwrap(aliceSession.current4DHVersions)
        XCTAssertFalse(aliceSession4DHVersions.local.rawValue > UInt32.max)
        XCTAssertEqual(ThreemaEnvironment.fsVersion.max, UInt32(aliceSession4DHVersions.local.rawValue))
        XCTAssertEqual(try aliceSession.state, .RL44)
        XCTAssertEqual(
            DHVersions.restored(
                local: CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max)),
                remote: CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
            ),
            aliceSession4DHVersions
        )
        XCTAssertEqual(
            aliceSession.outgoingOfferedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        XCTAssertEqual(
            aliceSession.outgoingAppliedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        XCTAssertEqual(
            aliceSession.minimumIncomingAppliedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        
        // Bob also has initiated a session with the maximum supported version
        let bobSession = try XCTUnwrap(bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: aliceContext.identityStore.identity
        ))
        let bobSession4DHVersions = try XCTUnwrap(bobSession.current4DHVersions)
        XCTAssertFalse(bobSession4DHVersions.local.rawValue > UInt32.max)
        XCTAssertEqual(ThreemaEnvironment.fsVersion.max, UInt32(bobSession4DHVersions.local.rawValue))
        XCTAssertEqual(try bobSession.state, .R24)
        XCTAssertEqual(
            DHVersions.restored(
                local: CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max)),
                remote: CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
            ),
            bobSession4DHVersions
        )
        XCTAssertEqual(
            bobSession.outgoingOfferedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        XCTAssertEqual(
            bobSession.outgoingAppliedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        XCTAssertEqual(
            bobSession.minimumIncomingAppliedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.min))
        )
        
        // Alice now sends a message with offered version 0x01FF (1.255)
        XCTAssertTrue(aliceContext.dhSessionStore is InMemoryDHSessionStore)
        
        let bestSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: bobContext.identityStore.identity
        ))
        bestSession.outgoingOfferedVersionOverride = CspE2eFs_Version(rawValue: 0x01FF)
        
        // We rely on the fact that aliceContext uses `InMemoryDHSessionStore` which stores a reference to this session
        // which means we can fill in the override as done above.
        XCTAssertNoThrow(try aliceContext.dhSessionStore.storeDHSession(session: bestSession))
        
        let message = try makeEncapTextMessage(
            text: ForwardSecurityMessageProcessorTests.aliceMessage2,
            senderContext: aliceContext
        )
        aliceContext.dummySender.sendMessage(abstractMessage: message.outerMessage, isPersistent: true)
        
        // Now Bob processes the text message from Alice. This should not fail, even if the applied version is not
        // known.
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage2,
            expectedMode: .fourDH
        )
        XCTAssertEqual(try bobSession.state, .RL44)
        XCTAssertEqual(
            DHVersions.restored(
                local: CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max)),
                remote: CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
            ),
            bobSession.current4DHVersions
        )
        XCTAssertEqual(
            bobSession.outgoingOfferedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        XCTAssertEqual(
            bobSession.outgoingAppliedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        XCTAssertEqual(
            bobSession.minimumIncomingAppliedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        
        // Assert that Alice did not receive session reject
        XCTAssertEqual(bobContext.dummySender.sentAbstractMessagesQueue.count, 0)
    }
    
    // TODO: (IOS-3949) Test changed
    func testMinorVersionDowngrade() async throws {
        // Alice and Bob support versions 1.x. Bob will later send a message with 1.0.

        // Alice starts negotiation
        XCTAssertNoThrow(try startNegotiationAlice())
        
        // Bob processes the init and the text message of alice
        _ = try await processReceivedMessages(senderContext: aliceContext, recipientContext: bobContext)
        
        // Alice should process the accept message now
        _ = try await processReceivedMessages(senderContext: bobContext, recipientContext: aliceContext)
        
        // Alice should now have initiated a session with the maximum supported version
        let aliceSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: bobContext.identityStore.identity
        ))
        let aliceSession4DHVersions = try XCTUnwrap(aliceSession.current4DHVersions)
        XCTAssertFalse(aliceSession4DHVersions.local.rawValue > UInt32.max)
        XCTAssertEqual(ThreemaEnvironment.fsVersion.max, UInt32(aliceSession4DHVersions.local.rawValue))
        XCTAssertEqual(try aliceSession.state, .RL44)
        XCTAssertEqual(
            DHVersions.restored(
                local: CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max)),
                remote: CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
            ),
            aliceSession4DHVersions
        )
        XCTAssertEqual(
            aliceSession.outgoingOfferedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        XCTAssertEqual(
            aliceSession.outgoingAppliedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        XCTAssertEqual(
            aliceSession.minimumIncomingAppliedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        
        // Bob also has initiated a session with the maximum supported version
        let bobSession = try XCTUnwrap(bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: aliceContext.identityStore.identity
        ))
        let bobSession4DHVersions = try XCTUnwrap(bobSession.current4DHVersions)
        XCTAssertFalse(bobSession4DHVersions.local.rawValue > UInt32.max)
        XCTAssertEqual(ThreemaEnvironment.fsVersion.max, UInt32(bobSession4DHVersions.local.rawValue))
        XCTAssertEqual(try bobSession.state, .R24)
        XCTAssertEqual(
            DHVersions.restored(
                local: CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max)),
                remote: CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
            ),
            bobSession4DHVersions
        )
        XCTAssertEqual(
            bobSession.outgoingOfferedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        XCTAssertEqual(
            bobSession.outgoingAppliedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.max))
        )
        XCTAssertEqual(
            bobSession.minimumIncomingAppliedVersion,
            CspE2eFs_Version(rawValue: Int(ThreemaEnvironment.fsVersion.min))
        )
        
        // Send message with applied version 0x0100 (1.0)
        XCTAssertTrue(aliceContext.dhSessionStore is InMemoryDHSessionStore)
        
        let bestSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: bobContext.identityStore.identity
        ))
        bestSession.outgoingOfferedVersionOverride = CspE2eFs_Version(rawValue: 0x0100)
        
        // We rely on the fact that aliceContext uses `InMemoryDHSessionStore` which stores a reference to this session
        // which means we can fill in the override as done above.
        XCTAssertNoThrow(try aliceContext.dhSessionStore.storeDHSession(session: bestSession))
        
        let message = try makeEncapTextMessage(
            text: ForwardSecurityMessageProcessorTests.aliceMessage2,
            senderContext: aliceContext
        )
        aliceContext.dummySender.sendMessage(abstractMessage: message.outerMessage, isPersistent: true)
        
        // Now Bob processes the text message from Alice. Note that the message should be rejected and therefore return
        // an empty list.
        let numberOfMessages =
            try await (processReceivedMessages(senderContext: aliceContext, recipientContext: bobContext)).count
        XCTAssertEqual(numberOfMessages, 0)
        XCTAssertNil(try? bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: aliceContext.identityStore.identity
        ))
        
        // Assert that Alice did receive a session reject
        XCTAssertEqual(bobContext.dummySender.sentAbstractMessagesQueue.count, 1)
        _ = try await processOneReceivedMessage(senderContext: bobContext, recipientContext: aliceContext)
        XCTAssertNil(try? aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: bobContext.identityStore.identity
        ))
    }
    
    func testDHSessionStates() async throws {
        // Alice and Bob support versions 1.x. Bob will later send a message with 1.0.

        // Alice starts negotiation
        XCTAssertNoThrow(try startNegotiationAlice())
        
        let aliceInitialSesionn = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: bobContext.identityStore.identity
        ))
        XCTAssertEqual(try aliceInitialSesionn.state, .L20)
        
        // Bob processes the init and should now have a session in state R24
        _ = try await processOneReceivedMessage(senderContext: aliceContext, recipientContext: bobContext)
        
        let bobInitialSession = try XCTUnwrap(bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: aliceContext.identityStore.identity
        ))
        XCTAssertEqual(try bobInitialSession.state, .R24)
        
        // Bob processes the text message
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage1,
            expectedMode: .twoDH
        )
        
        // Alice should now process the accept from Bob and update the state to L44
        _ = try await processOneReceivedMessage(senderContext: bobContext, recipientContext: aliceContext)
        
        let aliceFinalSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: bobContext.identityStore.identity
        ))
        XCTAssertEqual(try aliceFinalSession.state, .RL44)
        
        // Alice sends now again a message to Bob (with 4DH)
        XCTAssertNoThrow(try sendTextMessage(
            message: ForwardSecurityMessageProcessorTests.aliceMessage2,
            senderContext: aliceContext
        ))
        
        // Bob processes the text message and should update the state to R44
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage2,
            expectedMode: .fourDH
        )
        
        let bobFinalSession = try XCTUnwrap(bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: aliceContext.identityStore.identity
        ))
        XCTAssertEqual(try bobFinalSession.state, .RL44)
    }
    
    // MARK: - Private helper
    
    private func assertMessageTypeSupport(_ message: AbstractMessage, context: UserContext, supported: Bool) throws {
        do {
            let (_, outerMessage) = try aliceContext.fsmp.makeMessage(
                receiver: aliceContext.peerContact,
                innerMessage: message
            )
            
            XCTAssertEqual(outerMessage is ForwardSecurityEnvelopeMessage, supported)
        }
        catch {
            XCTFail()
        }
    }
    
    private func assertMessageTypeSupport(
        _ message: AbstractGroupMessage,
        context: UserContext,
        supported: Bool
    ) throws {
        message.groupID = groupIdentity.id
        message.groupCreator = groupIdentity.creator.string
        
        do {
            let (_, outerMessage) = try aliceContext.fsmp.makeMessage(
                receiver: aliceContext.peerContact,
                innerMessage: message
            )
            
            XCTAssertEqual(outerMessage is ForwardSecurityEnvelopeMessage, supported)
        }
        catch {
            XCTFail()
        }
    }
    
    private func setSupportedVersionRange(_ versionRange: CspE2eFs_VersionRange) {
        ThreemaEnvironment.fsVersion = versionRange
    }
    
    private func setupRaceCondition() throws {
        // Start the negotiation on Alice's side, up to the point where the Init and Message are
        // on the way to Bob, but have not been received by him yet
        try startNegotiationAlice()
        
        // Simulate a race condition: Before Bob has received the initial messages from Alice, he
        // starts his own negotiation and sends Alice a message
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.bobMessage2, senderContext: bobContext)
        
        // At this point, Bob has enqueued two FS messages: Init and Message.
        XCTAssertEqual(bobContext.dummySender.sentAbstractMessagesQueue.count, 2)
        
        // Bob should now have a (separate) 2DH session with Alice
        let alicesBestSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        ))
        let bobsBestSession = try XCTUnwrap(bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity
        ))
        XCTAssertNotEqual(alicesBestSession.id, bobsBestSession.id)
    }
    
    private func doTestRaceCondition1() async throws {
        // Set up a race condition: both sides have a 2DH session, but their mutual messages have not arrived yet
        try setupRaceCondition()
        
        // Let Alice process the messages that she has received from Bob.
        // The decapsulated message should be the 2DH text message from Bob.
        try await receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage2,
            expectedMode: .twoDH
        )
        
        // Now Bob finally gets the initial messages from Alice, after he has already started his own session.
        // The decapsulated message should be the 2DH text message from Alice.
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage1,
            expectedMode: .twoDH
        )
        
        // Bob now sends another message, this time in 4DH mode using the session with the lower ID
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.bobMessage3, senderContext: bobContext)
        
        // Alice receives this message, it should be in 4DH mode
        try await receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage3,
            expectedMode: .fourDH
        )
        
        // Alice also sends a message to Bob
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage6, senderContext: aliceContext)
        
        // Bob receives this message, it should be in 4DH mode
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage6,
            expectedMode: .fourDH
        )
        
        // Both sides should now agree on the best session
        try assertSameBestSession()
    }
    
    private func doTestRaceCondition2() async throws {
        // Set up a race condition: both sides have a 2DH session, but their mutual messages have not arrived yet
        try setupRaceCondition()
        
        // Let Alice process the messages that she has received from Bob.
        // The decapsulated message should be the 2DH text message from Bob.
        try await receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage2,
            expectedMode: .twoDH
        )
        
        // Alice now sends a message to Bob in 4DH mode
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage6, senderContext: aliceContext)
        
        // Now Bob finally gets the initial messages from Alice, after he has already started his own session.
        // The first decapsulated message should be the 2DH text message from Alice, and the second one should be in 4DH
        // mode.
        let receivedMessages = try await processReceivedMessages(
            senderContext: aliceContext,
            recipientContext: bobContext
        )
        XCTAssertEqual(receivedMessages.count, 2)
        XCTAssertEqual(
            (receivedMessages[0] as! BoxTextMessage).text,
            ForwardSecurityMessageProcessorTests.aliceMessage1
        )
        XCTAssertEqual(receivedMessages[0].forwardSecurityMode, .twoDH)
        XCTAssertEqual(
            (receivedMessages[1] as! BoxTextMessage).text,
            ForwardSecurityMessageProcessorTests.aliceMessage6
        )
        XCTAssertEqual(receivedMessages[1].forwardSecurityMode, .fourDH)
        
        // Bob now sends another message, this time in 4DH mode using the session with the lower ID
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.bobMessage3, senderContext: bobContext)
        
        // Alice receives this message, it should be in 4DH mode
        try await receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage3,
            expectedMode: .fourDH
        )
        
        // Alice now sends another message, this time in 4DH mode using the session with the lower ID
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage7, senderContext: aliceContext)
        
        // Bob receives this message, it should be in 4DH mode
        try await receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage7,
            expectedMode: .fourDH
        )
        
        // Both sides should now agree on the best session
        try assertSameBestSession()
    }
    
    private func assertSameBestSession() throws {
        // Alice and Bob should now each have one matching 4DH session
        let alicesBestSession = try XCTUnwrap(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        ))
        let bobsBestSession = try XCTUnwrap(bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity
        ))
        
        XCTAssertEqual(alicesBestSession.id, bobsBestSession.id)
    }
    
    private func makeAliceContext(localSupportedVersionRange: CspE2eFs_VersionRange = ThreemaEnvironment.fsVersion) {
        aliceContext = makeTestUserContext(
            myIdentity: aliceIdentity.string,
            mySecretKey: Data(base64Encoded: "2Hi7lA4boz9eLl0ozdeb2uKj2+i/wD2PUTRczwshp1Y=")!,
            peerIdentity: "BBBBBBBB",
            peerPublicKey: Data(base64Encoded: "oUEC0jPaUjqLqfEUXlCSSndLmwSg6d4/qA9XKKIJfSs=")!,
            localSupportedVersionRange: localSupportedVersionRange
        )
    }
    
    private func makeBobContext(localSupportedVersionRange: CspE2eFs_VersionRange = ThreemaEnvironment.fsVersion) {
        bobContext = makeTestUserContext(
            myIdentity: "BBBBBBBB",
            mySecretKey: Data(base64Encoded: "WE2g/Mu8jeGHMUX0pqyCP+ypW6gCu2xEBKESOyqgbn0=")!,
            peerIdentity: aliceIdentity.string,
            peerPublicKey: Data(base64Encoded: "CkgZmn3tqLS1YQHk2IF46hFK5ZdPhzayZjooLIvWxFo=")!,
            localSupportedVersionRange: ThreemaEnvironment.fsVersion
        )
    }
    
    private func startNegotiationAlice() throws {
        // Create context for Alice and Bob with mutual contact
        makeAliceContext()
        makeBobContext()
        
        // Alice now sends Bob a text message with forward security. No DH session exists,
        // so a new one has to be negotiated.
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage1, senderContext: aliceContext!)
        
        // At this point, Alice has enqueued two FS messages: Init and Message.
        XCTAssertEqual(aliceContext!.dummySender.sentAbstractMessagesQueue.count, 2)
        
        // Alice should now have a 2DH session with Bob
        let alicesInitiatorSession = try aliceContext!.dhSessionStore.bestDHSession(
            myIdentity: aliceContext!.identityStore.identity,
            peerIdentity: aliceContext!.peerContact.identity
        )!
        
        // The 2DH "my" ratchet counter should be 2 on Alice's side (as she has already incremented it
        // for the next message). There should be no peer 2DH ratchet, as it is never needed for the initiator.
        XCTAssertEqual(try XCTUnwrap(try? alicesInitiatorSession.state), .L20)
        XCTAssertNotNil(alicesInitiatorSession.myRatchet2DH)
        XCTAssertNil(alicesInitiatorSession.peerRatchet2DH)
        XCTAssertEqual(alicesInitiatorSession.myRatchet2DH!.counter, 2)
    }
    
    @discardableResult private func sendTextMessage(
        message: String,
        senderContext: UserContext
    ) throws -> AbstractMessage {
        let encapMessages = try makeEncapTextMessage(text: message, senderContext: senderContext)
        if let auxMessage = encapMessages.auxMessage {
            senderContext.dummySender.sendMessage(abstractMessage: auxMessage, isPersistent: true)
        }
        senderContext.dummySender.sendMessage(abstractMessage: encapMessages.outerMessage, isPersistent: true)
        
        // "Commit" message and set last update date if any message was an FS message
        if encapMessages.auxMessage != nil || encapMessages.outerMessage is ForwardSecurityEnvelopeMessage {
            try commitSentFSMessage(senderContext: senderContext)
        }
        
        return encapMessages.outerMessage
    }
    
    private func sendGroupTextMessage(
        message: String,
        senderContext: UserContext,
        groupIdentity: GroupIdentity
    ) throws {
        let encapMessages = try makeEncapGroupTextMessage(
            text: message,
            senderContext: senderContext,
            groupIdentity: groupIdentity
        )
        if let auxMessage = encapMessages.auxMessage {
            senderContext.dummySender.sendMessage(abstractMessage: auxMessage, isPersistent: true)
        }
        senderContext.dummySender.sendMessage(abstractMessage: encapMessages.outerMessage, isPersistent: true)
        
        // "Commit" message and set last update date if any message was an FS message
        if encapMessages.auxMessage != nil || encapMessages.outerMessage is ForwardSecurityEnvelopeMessage {
            try commitSentFSMessage(senderContext: senderContext)
        }
    }
    
    private func sendUnsupportedFSMessage(senderContext: UserContext) throws {
        let encapMessages = try makeEncapUnsupportedFSMessage(senderContext: senderContext)
        if let auxMessage = encapMessages.auxMessage {
            senderContext.dummySender.sendMessage(abstractMessage: auxMessage, isPersistent: true)
        }
        senderContext.dummySender.sendMessage(abstractMessage: encapMessages.outerMessage, isPersistent: true)
        
        // "Commit" message and set last update date if any message was an FS message
        if encapMessages.auxMessage != nil || encapMessages.outerMessage is ForwardSecurityEnvelopeMessage {
            try commitSentFSMessage(senderContext: senderContext)
        }
    }
    
    private func commitSentFSMessage(senderContext: UserContext) throws {
        let session = try XCTUnwrap(senderContext.dhSessionStore.bestDHSession(
            myIdentity: senderContext.identityStore.identity,
            peerIdentity: senderContext.peerContact.identity
        ))
        
        session.newSessionCommitted = true
        session.lastMessageSent = .now
        
        try senderContext.dhSessionStore.updateNewSessionCommitLastMessageSentDateAndVersions(session: session)
    }
    
    private func processReceivedMessages(
        senderContext: UserContext,
        recipientContext: UserContext
    ) async throws -> [AbstractMessage] {
        var decapsulatedMessages: [AbstractMessage] = []
        while !senderContext.dummySender.sentAbstractMessagesQueue.isEmpty {
            if let decap = try await processOneReceivedMessage(
                senderContext: senderContext,
                recipientContext: recipientContext
            ) {
                decapsulatedMessages.append(decap)
            }
        }
        return decapsulatedMessages
    }
    
    private func processOneReceivedMessage(
        senderContext: UserContext,
        recipientContext: UserContext
    ) async throws -> AbstractMessage? {
        guard !senderContext.dummySender.sentAbstractMessagesQueue.isEmpty else {
            XCTFail()
            return nil
        }
        
        let message = senderContext.dummySender.sentAbstractMessagesQueue.removeFirst()
        
        let (decap, fsMessageInfo) = try await recipientContext.fsmp.processEnvelopeMessage(
            sender: recipientContext.peerContact,
            envelopeMessage: message as! ForwardSecurityEnvelopeMessage
        )
        if let fsMessageInfo {
            _ = fsMessageInfo.updateVersionsIfNeeded() // Is this what we want?
            try recipientContext.dhSessionStore.storeDHSession(session: fsMessageInfo.session)
        }
        
        return decap
    }
    
    private func receiveAndAssertSingleMessage(
        senderContext: UserContext,
        recipientContext: UserContext,
        expectedMessage: String,
        expectedMode: ForwardSecurityMode
    ) async throws {
        let receivedMessages = try await processReceivedMessages(
            senderContext: senderContext,
            recipientContext: recipientContext
        )
        XCTAssertEqual(receivedMessages.count, 1)
        XCTAssertEqual((receivedMessages[0] as! BoxTextMessage).text, expectedMessage)
        XCTAssertEqual(receivedMessages[0].forwardSecurityMode, expectedMode)
    }
    
    private func receiveAndAssertSingleGroupMessage(
        senderContext: UserContext,
        recipientContext: UserContext,
        expectedMessage: String,
        expectedMode: ForwardSecurityMode,
        expectedGroupIdentity: GroupIdentity
    ) async throws {
        let receivedMessages = try await processReceivedMessages(
            senderContext: senderContext,
            recipientContext: recipientContext
        )
        XCTAssertEqual(receivedMessages.count, 1)
        let groupMessage = try XCTUnwrap(receivedMessages.first as? GroupTextMessage)
        XCTAssertEqual(groupMessage.text, expectedMessage)
        XCTAssertEqual(groupMessage.forwardSecurityMode, expectedMode)
        XCTAssertEqual(groupMessage.groupID, expectedGroupIdentity.id)
        XCTAssertEqual(groupMessage.groupCreator, expectedGroupIdentity.creator.string)
    }
    
    private func makeEncapTextMessage(
        text: String,
        senderContext: UserContext
    ) throws -> (
        auxMessage: ForwardSecurityEnvelopeMessage?,
        outerMessage: AbstractMessage
    ) {
        let textMessage = BoxTextMessage()
        textMessage.text = text
        textMessage.toIdentity = senderContext.peerContact.identity
        return try senderContext.fsmp.makeMessage(receiver: senderContext.peerContact, innerMessage: textMessage)
    }
    
    private func makeEncapGroupTextMessage(
        text: String,
        senderContext: UserContext,
        groupIdentity: GroupIdentity
    ) throws -> (
        auxMessage: ForwardSecurityEnvelopeMessage?,
        outerMessage: AbstractMessage
    ) {
        let groupTextMessage = GroupTextMessage()
        groupTextMessage.text = text
        groupTextMessage.toIdentity = senderContext.peerContact.identity
        groupTextMessage.groupID = groupIdentity.id
        groupTextMessage.groupCreator = groupIdentity.creator.string
        return try senderContext.fsmp.makeMessage(receiver: senderContext.peerContact, innerMessage: groupTextMessage)
    }
    
    private func makeEncapUnsupportedFSMessage(senderContext: UserContext) throws -> (
        auxMessage: ForwardSecurityEnvelopeMessage?,
        outerMessage: AbstractMessage
    ) {
        let unsupportedMessage = BoxAudioMessage()
        unsupportedMessage.toIdentity = senderContext.peerContact.identity
        XCTAssertEqual(unsupportedMessage.minimumRequiredForwardSecurityVersion(), .unspecified)
        return try senderContext.fsmp.makeMessage(receiver: senderContext.peerContact, innerMessage: unsupportedMessage)
    }
    
    private func makeTestUserContext(
        myIdentity: String,
        mySecretKey: Data,
        peerIdentity: String,
        peerPublicKey: Data,
        localSupportedVersionRange: CspE2eFs_VersionRange
    ) -> UserContext {
        let dhSessionStore = InMemoryDHSessionStore()
        let peerContact = ForwardSecurityContact(identity: peerIdentity, publicKey: peerPublicKey)
        let mockIdentityStore = MyIdentityStoreMock(identity: myIdentity, secretKey: mySecretKey)
        
        let messageSenderMock = MessageSenderMock()
        
        let fsmp = ForwardSecurityMessageProcessor(
            dhSessionStore: dhSessionStore,
            identityStore: mockIdentityStore,
            messageSender: messageSenderMock,
            localSupportedVersionRange: localSupportedVersionRange
        )
        
        return UserContext(
            peerContact: peerContact,
            dhSessionStore: dhSessionStore,
            identityStore: mockIdentityStore,
            fsmp: fsmp,
            dummySender: messageSenderMock
        )
    }
}

class RejectStatusListener: ForwardSecurityStatusListener {
    let expectation: XCTestExpectation
    var rejectedMessageID: Data?
    
    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }
    
    func sessionForMessageNotFound(
        in sessionDescription: String,
        messageID: String,
        contact: ThreemaFramework.ForwardSecurityContact
    ) {
        // Noop
    }
    
    func unexpectedNegotiatedVersion(
        in sessionDescription: String,
        appliedVersion: String,
        contact: ThreemaFramework.ForwardSecurityContact
    ) {
        // Noop
    }
    
    func rejectReceived(
        sessionID: DHSessionID,
        contact: ForwardSecurityContact,
        session: DHSession?,
        rejectedMessageID: Data,
        rejectCause: CspE2eFs_Reject.Cause,
        hasForwardSecuritySupport: Bool
    ) {
        self.rejectedMessageID = rejectedMessageID
        expectation.fulfill()
    }
    
    func negotiatedVersionUpdated(
        in sessionDescription: String,
        updatedNegotiatedVersion: ThreemaProtocols.CspE2eFs_Version,
        contact: ThreemaFramework.ForwardSecurityContact
    ) {
        // Noop
    }
    
    func messageOutOfOrder(
        sessionID: ThreemaFramework.DHSessionID,
        contact: ThreemaFramework.ForwardSecurityContact,
        messageID: Data
    ) {
        // Noop
    }
    
    func versionsUpdated(
        in session: ThreemaFramework.DHSession,
        versionUpdatedSnapshot: ThreemaFramework.UpdatedVersionsSnapshot,
        contact: ThreemaFramework.ForwardSecurityContact
    ) {
        // Noop
    }
    
    func messageWithoutFSReceived(
        in session: ThreemaFramework.DHSession,
        contactIdentity: String,
        message: AbstractMessage
    ) {
        // Noop
    }
    
    func illegalSessionState(identity: String, sessionID: ThreemaFramework.DHSessionID) {
        // Noop
    }
}

private struct UserContext {
    let peerContact: ForwardSecurityContact
    let dhSessionStore: DHSessionStoreProtocol
    let identityStore: MyIdentityStoreProtocol
    let fsmp: ForwardSecurityMessageProcessor
    let dummySender: MessageSenderMock
}
