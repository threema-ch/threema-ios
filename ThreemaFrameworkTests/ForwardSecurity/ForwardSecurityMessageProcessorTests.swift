//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
    static let bobMessage1 = "Hello Alice, glad to talk to you in 4DH mode!"
    static let bobMessage2 = "Hello Alice, I haven't heard from you yet!"
    static let bobMessage3 = "Let's see whose session we will use..."
    
    private var aliceContext: UserContext!
    private var bobContext: UserContext!
    
    override func setUp() {
        continueAfterFailure = false
        DDLog.add(DDOSLogger.sharedInstance)
    }
    
    func testNegotiationAnd2DH() throws {
        // Start the negotiation on Alice's side, up to the point where the Init and Message are
        // on the way to Bob, but have not been received by him yet
        try startNegotiationAlice()
        
        // Let Bob process all the messages that he has received from Alice.
        // The decapsulated message should be the text message from Alice.
        try receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage1,
            expectedMode: .twoDH
        )
        
        // At this point, Bob should have enqueued one FS message: Accept
        XCTAssertEqual(bobContext!.dummySender.queueSize, 1)
        
        // Let Alice process the Accept message that she has received from Bob
        let alicesReceivedMessages = try processReceivedMessages(
            senderContext: bobContext,
            recipientContext: aliceContext
        )
        
        // Bob has not sent any actual message to Alice
        XCTAssertEqual(alicesReceivedMessages.count, 0)
        
        // At this point, Alice and Bob should have one mutual 4DH session. Alice has already
        // discarded her 2DH ratchets.
        let alicesInitiatorSession = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        )!
        XCTAssertNil(alicesInitiatorSession.myRatchet2DH)
        XCTAssertNil(alicesInitiatorSession.peerRatchet2DH)
        XCTAssertNotNil(alicesInitiatorSession.myRatchet4DH)
        XCTAssertNotNil(alicesInitiatorSession.peerRatchet4DH)
        
        // Bob has not received a 4DH message yet, so he still has a 2DH peer ratchet
        let bobsResponderSession = try bobContext.dhSessionStore.exactDHSession(
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
    
    func test4DH() throws {
        try testNegotiationAnd2DH()
        
        // Check that we're in 4DH mode from the previous exchange
        try XCTAssertNotNil(aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext!.identityStore.identity,
            peerIdentity: aliceContext!.peerContact.identity
        ))
        
        // Alice now sends Bob another message, this time in 4DH mode
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage2, senderContext: aliceContext)
        
        // Let Bob process all the messages that he has received from Alice.
        // The decapsulated message should be the text message from Alice.
        try receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage2,
            expectedMode: .fourDH
        )
        
        // At this point, Bob should not have enqueued any further messages
        XCTAssertEqual(bobContext.dummySender.queueSize, 0)
        
        // Bob should have discarded his 2DH peer ratchet now
        let bobsResponderSession = try bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity
        )!
        XCTAssertNil(bobsResponderSession.peerRatchet2DH)
        
        // Bob now sends Alice a message in the new session
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.bobMessage1, senderContext: bobContext)
        
        // Let Alice process the messages that she has received from Bob.
        // The decapsulated message should be the text message from Bob.
        try receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage1,
            expectedMode: .fourDH
        )
    }
    
    func testMissingMessage() throws {
        try test4DH()
        
        // Alice now sends Bob another message, but it never arrives
        let encapResult = try makeEncapTextMessage(
            text: ForwardSecurityMessageProcessorTests.aliceMessage3,
            senderContext: aliceContext
        )
        try encapResult.sendCompletion()
        
        // Drop this message.
        
        // Alice now sends Bob another message, which arrives and should be decodable
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage4, senderContext: aliceContext)
        
        // Let Bob process all the messages that he has received from Alice.
        // The decapsulated message should be the text message from Alice.
        try receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage4,
            expectedMode: .fourDH
        )
        
        // At this point, Bob should not have enqueued any further messages
        XCTAssertEqual(bobContext.dummySender.queueSize, 0)
    }
    
    func testDataLoss() throws {
        // Repeat the tests several times, as random session IDs are involved
        for _ in 1...ForwardSecurityMessageProcessorTests.numRandomRuns {
            try doTestDataLoss1()
            try doTestDataLoss2()
        }
    }
    
    private func setupDataLoss() throws {
        try test4DH()
        
        // Check that Bob has a responder DH session that matches Alice's initiator session.
        let alicesSession = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        )!
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
    
    private func doTestDataLoss1() throws {
        // Data loss scenario 1: Bob loses his data, but does not send any messages until Alice
        // sends her first message after the data loss. This message gets rejected by Bob, and eventually
        // both agree on a new 4DH session.
        try setupDataLoss()
        
        // Set up expectation that the failure listener is invoked on Alice's side
        let listener = RejectStatusListener(expectation: expectation(description: "rejectReceived"))
        aliceContext.fsmp.addListener(listener: listener)
        
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
        let bobsReceivedMessages = try processReceivedMessages(
            senderContext: aliceContext,
            recipientContext: bobContext
        )
        
        // There should be no decrypted messages
        XCTAssertEqual(bobsReceivedMessages.count, 0)
        
        // Bob should have enqueued one FS message (a reject) to Alice.
        XCTAssertEqual(bobContext.dummySender.queueSize, 1)
        
        // Let Alice process the reject message that she has received from Bob.
        let alicesReceivedMessages = try processReceivedMessages(
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
        waitForExpectations(timeout: 0)
        XCTAssertEqual(listener.rejectedMessageID, encapMessage.messageID)
    }
    
    private func doTestDataLoss2() throws {
        // Data loss scenario 2: Bob loses his data and sends a message in a new session before
        // Alice gets a chance to send one. Alice should take the Init from Bob as a hint that he
        // has lost his session data, and she should discard the existing (4DH) session.
        try setupDataLoss()
        
        // Bob sends Alice a message, and since he doesn't have a session anymore, he starts a new one
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.bobMessage2, senderContext: bobContext)
        
        // Let Alice process all the messages that she has received from Bob.
        try receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage2,
            expectedMode: .twoDH
        )
        
        // Alice should have enqueued an Accept for the new session to Bob
        XCTAssertEqual(aliceContext.dummySender.queueSize, 1)
        
        // Alice now sends a message to Bob, which should be in 4DH mode
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage6, senderContext: aliceContext)
        
        // Let Bob process the messages that he has received from Alice.
        try receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage6,
            expectedMode: .fourDH
        )
        
        // Alice and Bob should now each have one matching 4DH session
        let alicesBestSession = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        )!
        let bobsBestSession = try bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity
        )!
        
        XCTAssertEqual(alicesBestSession.id, bobsBestSession.id)
    }
    
    func testDowngrade() throws {
        try test4DH()
        
        // Bob has received a 4DH message from Alice, and thus both parties should
        // not have a 2DH session anymore
        let alicesSession = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        )!
        let bobsSession = try bobContext.dhSessionStore.exactDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity,
            sessionID: alicesSession.id
        )!
        XCTAssertNil(alicesSession.myRatchet2DH)
        XCTAssertNil(alicesSession.peerRatchet2DH)
        XCTAssertNil(bobsSession.myRatchet2DH)
        XCTAssertNil(bobsSession.peerRatchet2DH)
    }
    
    func testSendAuxFailure() throws {
        makeAliceContext()

        let encapMessages = try makeEncapTextMessage(text: "Test", senderContext: aliceContext)

        // Alice should now have a 2DH session with Bob
        let alicesInitiatorSession = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        )!
        XCTAssertNotNil(alicesInitiatorSession.myRatchet2DH)

        // Simulate init message send failure
        encapMessages.sendAuxFailure()

        // Alice's session should now be deleted
        let alicesInitiatorSession2 = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        )
        XCTAssertNil(alicesInitiatorSession2)
    }
    
    func testRaceConditions() throws {
        
        // Repeat the tests several times, as random session IDs are involved
        for _ in 1...ForwardSecurityMessageProcessorTests.numRandomRuns {
            try doTestRaceCondition1()
            try doTestRaceCondition2()
        }
    }
    
    private func setupRaceCondition() throws {
        // Start the negotiation on Alice's side, up to the point where the Init and Message are
        // on the way to Bob, but have not been received by him yet
        try startNegotiationAlice()
        
        // Simulate a race condition: Before Bob has received the initial messages from Alice, he
        // starts his own negotiation and sends Alice a message
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.bobMessage2, senderContext: bobContext)
        
        // At this point, Bob has enqueued two FS messages: Init and Message.
        XCTAssertEqual(bobContext.dummySender.queueSize, 2)
        
        // Bob should now have a (separate) 2DH session with Alice
        let alicesBestSession = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        )!
        let bobsBestSession = try bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity
        )!
        XCTAssertNotEqual(alicesBestSession.id, bobsBestSession.id)
    }
    
    private func doTestRaceCondition1() throws {
        // Set up a race condition: both sides have a 2DH session, but their mutual messages have not arrived yet
        try setupRaceCondition()
        
        // Let Alice process the messages that she has received from Bob.
        // The decapsulated message should be the 2DH text message from Bob.
        try receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage2,
            expectedMode: .twoDH
        )
        
        // Now Bob finally gets the initial messages from Alice, after he has already started his own session.
        // The decapsulated message should be the 2DH text message from Alice.
        try receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage1,
            expectedMode: .twoDH
        )
        
        // Bob now sends another message, this time in 4DH mode using the session with the lower ID
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.bobMessage3, senderContext: bobContext)
        
        // Alice receives this message, it should be in 4DH mode
        try receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage3,
            expectedMode: .fourDH
        )
        
        // Alice also sends a message to Bob
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage6, senderContext: aliceContext)
        
        // Bob receives this message, it should be in 4DH mode
        try receiveAndAssertSingleMessage(
            senderContext: aliceContext,
            recipientContext: bobContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.aliceMessage6,
            expectedMode: .fourDH
        )
        
        // Both sides should now agree on the best session
        try assertSameBestSession()
    }
    
    private func doTestRaceCondition2() throws {
        // Set up a race condition: both sides have a 2DH session, but their mutual messages have not arrived yet
        try setupRaceCondition()
        
        // Let Alice process the messages that she has received from Bob.
        // The decapsulated message should be the 2DH text message from Bob.
        try receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage2,
            expectedMode: .twoDH
        )
        
        // Alice now sends a message to Bob in 4DH mode
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage6, senderContext: aliceContext)
        
        // Now Bob finally gets the initial messages from Alice, after he has already started his own session.
        // The first decapsulated message should be the 2DH text message from Alice, and the second one should be in 4DH mode.
        let receivedMessages = try processReceivedMessages(senderContext: aliceContext, recipientContext: bobContext)
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
        try receiveAndAssertSingleMessage(
            senderContext: bobContext,
            recipientContext: aliceContext,
            expectedMessage: ForwardSecurityMessageProcessorTests.bobMessage3,
            expectedMode: .fourDH
        )
        
        // Alice now sends another message, this time in 4DH mode using the session with the lower ID
        try sendTextMessage(message: ForwardSecurityMessageProcessorTests.aliceMessage7, senderContext: aliceContext)
        
        // Bob receives this message, it should be in 4DH mode
        try receiveAndAssertSingleMessage(
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
        let alicesBestSession = try aliceContext.dhSessionStore.bestDHSession(
            myIdentity: aliceContext.identityStore.identity,
            peerIdentity: aliceContext.peerContact.identity
        )!
        let bobsBestSession = try bobContext.dhSessionStore.bestDHSession(
            myIdentity: bobContext.identityStore.identity,
            peerIdentity: bobContext.peerContact.identity
        )!
        
        XCTAssertEqual(alicesBestSession.id, bobsBestSession.id)
    }
    
    private func makeAliceContext() {
        aliceContext = makeTestUserContext(
            myIdentity: "AAAAAAAA",
            mySecretKey: Data(base64Encoded: "2Hi7lA4boz9eLl0ozdeb2uKj2+i/wD2PUTRczwshp1Y=")!,
            peerIdentity: "BBBBBBBB",
            peerPublicKey: Data(base64Encoded: "oUEC0jPaUjqLqfEUXlCSSndLmwSg6d4/qA9XKKIJfSs=")!
        )
    }
    
    private func makeBobContext() {
        bobContext = makeTestUserContext(
            myIdentity: "BBBBBBBB",
            mySecretKey: Data(base64Encoded: "WE2g/Mu8jeGHMUX0pqyCP+ypW6gCu2xEBKESOyqgbn0=")!,
            peerIdentity: "AAAAAAAA",
            peerPublicKey: Data(base64Encoded: "CkgZmn3tqLS1YQHk2IF46hFK5ZdPhzayZjooLIvWxFo=")!
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
        XCTAssertEqual(aliceContext!.dummySender.queueSize, 2)
        
        // Alice should now have a 2DH session with Bob
        let alicesInitiatorSession = try aliceContext!.dhSessionStore.bestDHSession(
            myIdentity: aliceContext!.identityStore.identity,
            peerIdentity: aliceContext!.peerContact.identity
        )!
        
        // The 2DH "my" ratchet counter should be 2 on Alice's side (as she has already incremented it
        // for the next message). There should be no peer 2DH ratchet, as it is never needed for the initiator.
        XCTAssertNotNil(alicesInitiatorSession.myRatchet2DH)
        XCTAssertNil(alicesInitiatorSession.peerRatchet2DH)
        XCTAssertEqual(alicesInitiatorSession.myRatchet2DH!.counter, 2)
    }
    
    @discardableResult private func sendTextMessage(
        message: String,
        senderContext: UserContext
    ) throws -> ForwardSecurityEnvelopeMessage {
        let encapMessages = try makeEncapTextMessage(text: message, senderContext: senderContext)
        try encapMessages.sendCompletion()
        if let auxMessage = encapMessages.auxMessage {
            senderContext.dummySender.send(message: auxMessage)
        }
        senderContext.dummySender.send(message: encapMessages.message)
        return encapMessages.message
    }
    
    private func processReceivedMessages(
        senderContext: UserContext,
        recipientContext: UserContext
    ) throws -> [AbstractMessage] {
        var decapsulatedMessages: [AbstractMessage] = []
        while let message = senderContext.dummySender.popMessage() {
            let (decap, _) = try recipientContext.fsmp.processEnvelopeMessage(
                sender: recipientContext.peerContact,
                envelopeMessage: message as! ForwardSecurityEnvelopeMessage
            )
            
            if let decap {
                decapsulatedMessages.append(decap)
            }
        }
        return decapsulatedMessages
    }
    
    private func receiveAndAssertSingleMessage(
        senderContext: UserContext,
        recipientContext: UserContext,
        expectedMessage: String,
        expectedMode: ForwardSecurityMode
    ) throws {
        let receivedMessages = try processReceivedMessages(
            senderContext: senderContext,
            recipientContext: recipientContext
        )
        XCTAssertEqual(receivedMessages.count, 1)
        XCTAssertEqual((receivedMessages[0] as! BoxTextMessage).text, expectedMessage)
        XCTAssertEqual(receivedMessages[0].forwardSecurityMode, expectedMode)
    }
    
    private func makeEncapTextMessage(
        text: String,
        senderContext: UserContext
    ) throws
        -> (
            auxMessage: ForwardSecurityEnvelopeMessage?,
            message: ForwardSecurityEnvelopeMessage,
            sendCompletion: () throws -> Void,
            sendAuxFailure: () -> Void
        ) {
        let textMessage = BoxTextMessage()
        textMessage.text = text
        textMessage.toIdentity = senderContext.peerContact.identity
        return try senderContext.fsmp.makeMessage(contact: senderContext.peerContact, innerMessage: textMessage)
    }
    
    private func makeTestUserContext(
        myIdentity: String,
        mySecretKey: Data,
        peerIdentity: String,
        peerPublicKey: Data
    ) -> UserContext {
        let dhSessionStore = InMemoryDHSessionStore()
        let peerContact = ForwardSecurityContact(identity: peerIdentity, publicKey: peerPublicKey)
        let mockIdentityStore = MyIdentityStoreMock(identity: myIdentity, secretKey: mySecretKey)
        
        let dummySender = DummySender()
        
        let fsmp = ForwardSecurityMessageProcessor(
            dhSessionStore: dhSessionStore,
            identityStore: mockIdentityStore,
            messageSender: dummySender
        )
        
        return UserContext(
            peerContact: peerContact,
            dhSessionStore: dhSessionStore,
            identityStore: mockIdentityStore,
            fsmp: fsmp,
            dummySender: dummySender
        )
    }
}

class DummySender: ForwardSecurityMessageSenderProtocol {
    var messageQueue: [AbstractMessage] = []
    
    func send(message: AbstractMessage) {
        messageQueue.append(message)
    }
    
    func popMessage() -> AbstractMessage? {
        if messageQueue.isEmpty {
            return nil
        }
        return messageQueue.removeFirst()
    }
    
    var queueSize: Int {
        messageQueue.count
    }
}

class RejectStatusListener: ForwardSecurityStatusListener {
    let expectation: XCTestExpectation
    var rejectedMessageID: Data?
    
    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }
    
    func rejectReceived(sessionID: DHSessionID, contact: ForwardSecurityContact, rejectedMessageID: Data) {
        self.rejectedMessageID = rejectedMessageID
        expectation.fulfill()
    }
}

private struct UserContext {
    let peerContact: ForwardSecurityContact
    let dhSessionStore: DHSessionStoreProtocol
    let identityStore: MyIdentityStoreProtocol
    let fsmp: ForwardSecurityMessageProcessor
    let dummySender: DummySender
}
