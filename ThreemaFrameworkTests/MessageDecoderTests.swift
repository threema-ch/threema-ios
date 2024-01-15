//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
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

import XCTest
@testable import ThreemaFramework

class MessageDecoderTests: XCTestCase {
    
    private var mainCnx: NSManagedObjectContext!
    var databaseCnx: DatabaseContext!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        databaseCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Should return nil for invalid messages
    func testDecodeInvalidMessage() {
        let type: Int32 = MSGTYPE_LOCATION
        let data: Data = "test".data(using: .utf8)!

        let result = MessageDecoder.decode(type, body: data)

        XCTAssertNil(result)
    }

    /// Should return unkown type message for unknown types
    func testDecodeUnknownType() {
        let type: Int32 = 0xFF
        let data: Data = "test".data(using: .utf8)!

        let result = MessageDecoder.decode(type, body: data)

        XCTAssertTrue(result is UnknownTypeMessage)
    }
    
    func testDecodeBoxAudioMessage() {
        let msg = BoxAudioMessage()
        msg.duration = 1
        msg.audioBlobID = Data(BytesUtility.padding([], pad: 0x03, length: ThreemaProtocol.blobIDLength))
        msg.audioSize = 10
        msg.encryptionKey = Data(BytesUtility.padding([], pad: 0x04, length: Int(kBlobKeyLen)))
        
        let result = MessageDecoder.decode(MSGTYPE_AUDIO, body: msg.body()) as? BoxAudioMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.duration, msg.duration)
        XCTAssertEqual(result?.audioBlobID, msg.audioBlobID)
        XCTAssertEqual(result?.audioSize, msg.audioSize)
        XCTAssertEqual(result?.encryptionKey, msg.encryptionKey)
    }

    func testDecodeDeliveryReceiptMessage() {
        let msg = DeliveryReceiptMessage()
        msg.receiptMessageIDs = [Data(BytesUtility.padding([], pad: 0xEF, length: ThreemaProtocol.messageIDLength))]
        msg.receiptType = .read
        
        let result = MessageDecoder.decode(MSGTYPE_DELIVERY_RECEIPT, body: msg.body()) as? DeliveryReceiptMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.receiptMessageIDs.count, 1)
        XCTAssertEqual(result?.receiptType, msg.receiptType)
    }
    
    func testDecodeBoxBallotCreateMessage() {
        let msg = newBoxBallotCreateMessage(["type": "ballot create"])
        let result = MessageDecoder.decode(MSGTYPE_BALLOT_CREATE, body: msg.body()) as? BoxBallotCreateMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.ballotID, msg.ballotID)
        XCTAssertEqual(result?.jsonData, msg.jsonData)
    }
    
    func testDecodeBoxUpdateExtistingBallot() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        let expectedResults = [
            ["Choice 1", "Choice 2", [
                "d": "Testtitle",
                "t": 0,
                "s": 0,
                "c": [["i": 2_222_222, "n": "Choice 1", "o": 0] as [String: Any],
                      ["i": 2_222_223, "n": "Choice 2", "o": 1]],
                "o": 0,
                "a": 0,
            ] as [String: Any]] as [Any],
            [
                "Choice 1",
                "Choice 2",
                [
                    "d": "Testtitle 2",
                    "t": 0,
                    "s": 0,
                    "c": [["i": 2_222_224, "n": "Choice 3", "o": 0] as [String: Any],
                          ["i": 2_222_225, "n": "Choice 4", "o": 1]],
                    "o": 0,
                    "a": 0,
                ] as [String: Any],
            ],
        ]

        let (_, conversation) = createConversation()
        let ballotMessageDecoder =
            BallotMessageDecoder(EntityManager(databaseContext: databaseCnx, myIdentityStore: myIdentityStoreMock))

        for result in expectedResults {
            let msg = newBoxBallotCreateMessage(result[2])

            let boxBallotCreateMessage = try XCTUnwrap(
                MessageDecoder.decode(
                    MSGTYPE_BALLOT_CREATE,
                    body: msg.body()
                ) as? BoxBallotCreateMessage
            )
            boxBallotCreateMessage.fromIdentity = "ECHOECHO"

            let expect = expectation(description: "Decode and create ballot")

            var ballotMessage: BallotMessage?
            ballotMessageDecoder!.decodeCreateBallot(
                fromBox: boxBallotCreateMessage,
                sender: nil,
                conversation: conversation,
                onCompletion: { message in
                    ballotMessage = message
                    expect.fulfill()
                },
                onError: { error in
                    XCTFail("\(error)")
                    expect.fulfill()
                }
            )

            wait(for: [expect], timeout: 3)

            checkBallotResult(ballotMessage: ballotMessage, result: result)
        }
    }

    func testDecodeBoxCloseExistingBallot() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        let expectedResults = [
            ["Choice 1", "Choice 2", 0, [
                "d": "Testtitle",
                "t": 0,
                "s": 0,
                "c": [["i": 2_222_222, "n": "Choice 1", "o": 0] as [String: Any],
                      ["i": 2_222_223, "n": "Choice 2", "o": 1]],
                "o": 0,
                "a": 0,
            ] as [String: Any]] as [Any],
            [
                "Choice 1",
                "Choice 2",
                1,
                [
                    "d": "Testtitle",
                    "t": 0,
                    "s": 1,
                    "c": [["i": 2_222_222, "n": "Choice 1", "o": 0] as [String: Any],
                          ["i": 2_222_223, "n": "Choice 2", "o": 1]],
                    "o": 0,
                    "a": 1,
                ] as [String: Any],
            ],
        ]

        let (_, conversation) = createConversation()
        let ballotMessageDecoder =
            BallotMessageDecoder(EntityManager(databaseContext: databaseCnx, myIdentityStore: myIdentityStoreMock))

        for result in expectedResults {
            let msg = newBoxBallotCreateMessage(result[3])

            let boxBallotCreateMessage = try XCTUnwrap(
                MessageDecoder.decode(
                    MSGTYPE_BALLOT_CREATE,
                    body: msg.body()
                ) as? BoxBallotCreateMessage
            )
            boxBallotCreateMessage.fromIdentity = "ECHOECHO"

            let expect = expectation(description: "Decode and create ballot")

            var ballotMessage: BallotMessage?
            ballotMessageDecoder!.decodeCreateBallot(
                fromBox: boxBallotCreateMessage,
                sender: nil,
                conversation: conversation,
                onCompletion: { message in
                    ballotMessage = message
                    expect.fulfill()
                },
                onError: { error in
                    XCTFail("\(error)")
                    expect.fulfill()
                }
            )

            wait(for: [expect], timeout: 3)

            XCTAssertEqual(ballotMessage?.ballotState, result[2] as? NSNumber)

            checkBallotResult(ballotMessage: ballotMessage, result: result)
        }
    }

    func testDecodeBoxCloseWrongExistingBallot() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        let expectedResults = [
            // Initial Message
            [
                "Choice 1", // Expected Result
                "Choice 2", // Expected 2nd Choice
                0,
                "Testtitle",
                [
                    "d": "Testtitle",
                    "t": 0,
                    "s": 0,
                    "c": [
                        [
                            "i": 2_222_222,
                            "n": "Choice 1",
                            "o": 0,
                        ] as [String: Any],
                        [
                            "i": 2_222_223,
                            "n": "Choice 2",
                            "o": 1,
                        ],
                    ],
                    "o": 0,
                    "a": 0,
                ] as [String: Any],
            ] as [Any],
            // Result Message
            [
                "Choice 4", // Expected Result
                "Choice 3", // Expected 2nd Choice
                1,
                "Testtitle",
                [
                    "d": "Testtitle 1",
                    "t": 0,
                    "s": 1,
                    "c": [
                        [
                            "i": 2_222_222,
                            "n": "Choice 3",
                            "o": 1,
                        ] as [String: Any],
                        [
                            "i": 2_222_223,
                            "n": "Choice 4",
                            "o": 0,
                        ],
                    ],
                    "o": 0,
                    "a": 1,
                ] as [String: Any],
            ],
        ]

        let (_, conversation) = createConversation()
        let ballotMessageDecoder =
            BallotMessageDecoder(EntityManager(databaseContext: databaseCnx, myIdentityStore: myIdentityStoreMock))

        // Initial Incoming Ballot Message
        let initialResult = expectedResults[0]
        let initialMessage = newBoxBallotCreateMessage(initialResult[4])

        let boxBallotCreateInitialMessage = try XCTUnwrap(
            MessageDecoder.decode(
                MSGTYPE_BALLOT_CREATE,
                body: initialMessage.body()
            ) as? BoxBallotCreateMessage
        )
        boxBallotCreateInitialMessage.fromIdentity = "ECHOECHO"

        let expectInitial = expectation(description: "Decode and create initial ballot")

        var ballotInitialMessage: BallotMessage?
        ballotMessageDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateInitialMessage,
            sender: nil,
            conversation: conversation,
            onCompletion: { message in
                ballotInitialMessage = message
                expectInitial.fulfill()
            },
            onError: { error in
                XCTFail("\(error)")
                expectInitial.fulfill()
            }
        )

        wait(for: [expectInitial], timeout: 3)

        // Check Initial Choices exist
        let initialChoicesSet = (ballotInitialMessage?.ballot.choices!)! as NSSet
        let initialChoicesArray = initialChoicesSet.allObjects as! [BallotChoice]
        let initialChoicesSorted = initialChoicesArray.sorted { $0.orderPosition.intValue <= $1.orderPosition.intValue
        }

        // Most Voted
        let inititalChoice1 = initialChoicesSorted.first!
        // Less Voted
        let inititalChoice2 = initialChoicesSorted.last!

        XCTAssertEqual(inititalChoice1.name, initialResult[0] as? String)
        XCTAssertEqual(inititalChoice2.name, initialResult[1] as? String)

        // Closing Ballot Message With different Results
        let differentResult = expectedResults[1]
        let resultMessage = newBoxBallotCreateMessage(differentResult[4])

        let boxBallotCreateResultMessage = try XCTUnwrap(
            MessageDecoder.decode(
                MSGTYPE_BALLOT_CREATE,
                body: resultMessage.body()
            ) as? BoxBallotCreateMessage
        )
        boxBallotCreateResultMessage.fromIdentity = "ECHOECHO"

        let expect = expectation(description: "Decode and create ballot")

        ballotMessageDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateResultMessage,
            sender: nil,
            conversation: conversation,
            onCompletion: { _ in
                expect.fulfill()
            },
            onError: { error in
                XCTFail("\(error)")
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 3)

        // Check Results Message Overrides Initial (Local) Message
        let resultChoicesSet = (ballotInitialMessage?.ballot.choices!)! as NSSet
        let resultChoicesArray = resultChoicesSet.allObjects as! [BallotChoice]
        let resultChoicesSorted = resultChoicesArray.sorted { $0.orderPosition.intValue <= $1.orderPosition.intValue }

        // Most Voted
        let resultChoice1 = resultChoicesSorted.first!
        // Less Voted
        let resultChoice2 = resultChoicesSorted.last!

        XCTAssertEqual(resultChoice1.name, differentResult[0] as? String)
        XCTAssertEqual(resultChoice2.name, differentResult[1] as? String)
    }
    
    private func createConversation() -> (ContactEntity, Conversation) {
        var contact: ContactEntity!
        var conversation: Conversation!
        
        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            contact = databasePreparer.createContact(publicKey: Data([1]), identity: "ECHOECHO", verificationLevel: 0)
            
            conversation = databasePreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.contact = contact
                }
        }
        
        return (contact, conversation)
    }
    
    func testDecodeBoxBallotVoteMessage() {
        let msg = BoxBallotVoteMessage()
        msg.ballotCreator = "TESTID12"
        msg.ballotID = Data(BytesUtility.padding([], pad: 0x99, length: ThreemaProtocol.ballotIDLength))
        msg.jsonChoiceData = "{type: 'ballot vote'}".data(using: .utf8)

        let result = MessageDecoder.decode(MSGTYPE_BALLOT_VOTE, body: msg.body()) as? BoxBallotVoteMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.ballotCreator, msg.ballotCreator)
        XCTAssertEqual(result?.ballotID, msg.ballotID)
        XCTAssertEqual(result?.jsonChoiceData, msg.jsonChoiceData)
    }
    
    func testDecodeBoxFileMessage() {
        let msg = BoxFileMessage()
        msg.jsonData = "{type: 'file'}".data(using: .utf8)
        
        let result = MessageDecoder.decode(MSGTYPE_FILE, body: msg.body()) as? BoxFileMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.jsonData, msg.jsonData)
    }
    
    func testDecodeBoxImageMessage() {
        let msg = BoxImageMessage()
        msg.blobID = Data(BytesUtility.padding([], pad: 0x01, length: ThreemaProtocol.blobIDLength))
        msg.imageNonce = Data(BytesUtility.padding([], pad: 0x02, length: Int(kNonceLen)))
        msg.size = 3

        let result = MessageDecoder.decode(MSGTYPE_IMAGE, body: msg.body()) as? BoxImageMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.blobID, msg.blobID)
        XCTAssertEqual(result?.imageNonce, msg.imageNonce)
        XCTAssertEqual(result?.size, 3)
    }
    
    func testDecodeBoxLocationMessage() throws {
        let msg = "47.201515,8.783403,65.000000".data(using: .utf8)
        
        let result = try XCTUnwrap(MessageDecoder.decode(MSGTYPE_LOCATION, body: msg) as? BoxLocationMessage)
        
        XCTAssertEqual(result.latitude, 47.201515)
        XCTAssertEqual(result.longitude, 8.783403)
        XCTAssertEqual(result.accuracy, 65.000000)
    }
    
    func testDecodeBoxLocationMessageNoPoiName() throws {
        let msg = "47.201515,8.783403,65.000000\n\ntestAddress".data(using: .utf8)
        
        let result = try XCTUnwrap(MessageDecoder.decode(MSGTYPE_LOCATION, body: msg) as? BoxLocationMessage)
        
        XCTAssertEqual(result.latitude, 47.201515)
        XCTAssertEqual(result.longitude, 8.783403)
        XCTAssertEqual(result.accuracy, 65.000000)
        XCTAssertEqual(result.poiName, "")
        XCTAssertEqual(result.poiAddress, "testAddress")
    }
    
    func testDecodeBoxLocationMessageAddress() throws {
        let msg = "47.201515,8.783403,65.000000\ntestName\ntestAddress\\nline2".data(using: .utf8)
        
        let result = try XCTUnwrap(MessageDecoder.decode(MSGTYPE_LOCATION, body: msg) as? BoxLocationMessage)
        
        XCTAssertEqual(result.latitude, 47.201515)
        XCTAssertEqual(result.longitude, 8.783403)
        XCTAssertEqual(result.accuracy, 65.000000)
        XCTAssertEqual(result.poiName, "testName")
        XCTAssertEqual(result.poiAddress, "testAddress\nline2")
    }
    
    func testDecodeBoxTextMessage() throws {
        let msg = BoxTextMessage()
        msg.text = "Muttis diweiss"
        
        let result = MessageDecoder.decode(MSGTYPE_TEXT, body: msg.body()) as? BoxTextMessage

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.text, "Muttis diweiss")
        XCTAssertNil(result?.quotedMessageID)
        XCTAssertEqual(
            try String(data: XCTUnwrap(result?.quotedBody()), encoding: .utf8),
            "Muttis diweiss"
        )
    }
    
    func testDecodeBoxTextMessageQuoted() throws {
        let expectedQuotedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedQuotedText = QuoteUtil.generateText("Muttis diweiss", with: expectedQuotedMessageID)

        let msg = BoxTextMessage()
        msg.text = expectedQuotedText
        msg.quotedMessageID = expectedQuotedMessageID

        let result = MessageDecoder.decode(MSGTYPE_TEXT, body: msg.body()) as? BoxTextMessage

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.text, "Muttis diweiss")
        XCTAssertEqual(result?.quotedMessageID, expectedQuotedMessageID)
        XCTAssertEqual(
            try String(data: XCTUnwrap((XCTUnwrap(result) as QuotedMessageProtocol).quotedBody()), encoding: .utf8),
            expectedQuotedText
        )
    }

    func testDecodeBoxVideoMessage() {
        let msg = BoxVideoMessage()
        msg.duration = 1
        msg.encryptionKey = Data(BytesUtility.padding([], pad: 0x02, length: Int(kBlobKeyLen)))
        msg.thumbnailBlobID = Data(BytesUtility.padding([], pad: 0x03, length: ThreemaProtocol.blobIDLength))
        msg.thumbnailSize = 3
        msg.videoBlobID = Data(BytesUtility.padding([], pad: 0x04, length: ThreemaProtocol.blobIDLength))
        msg.videoSize = 2
        
        let result = MessageDecoder.decode(MSGTYPE_VIDEO, body: msg.body()) as? BoxVideoMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.duration, msg.duration)
        XCTAssertEqual(result?.encryptionKey, msg.encryptionKey)
        XCTAssertEqual(result?.thumbnailBlobID, msg.thumbnailBlobID)
        XCTAssertEqual(result?.thumbnailSize, msg.thumbnailSize)
        XCTAssertEqual(result?.videoBlobID, msg.videoBlobID)
        XCTAssertEqual(result?.videoSize, msg.videoSize)
    }
    
    func testDecodeBoxVoIPCallAnswerMessage() {
        let msg = BoxVoIPCallAnswerMessage() // Data()
        msg.jsonData = "{type: 'call answer'}".data(using: .utf8)
        
        let result = MessageDecoder.decode(MSGTYPE_VOIP_CALL_ANSWER, body: msg.body()) as? BoxVoIPCallAnswerMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.jsonData, msg.jsonData)
    }
    
    func testDecodeBoxVoIPCallHangupMessage() {
        let result = MessageDecoder.decode(MSGTYPE_VOIP_CALL_HANGUP, body: Data()) as? BoxVoIPCallHangupMessage
        
        XCTAssertNotNil(result)
    }
    
    func testDecodeBoxVoIPCallIceCandidatesMessage() {
        let msg = BoxVoIPCallIceCandidatesMessage()
        msg.jsonData = "{type: 'call icecandidate'}".data(using: .utf8)
        
        let result = MessageDecoder.decode(
            MSGTYPE_VOIP_CALL_ICECANDIDATE,
            body: msg.body()
        ) as? BoxVoIPCallIceCandidatesMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.jsonData, msg.jsonData)
    }
    
    func testDecodeBoxVoIPCallOfferMessage() {
        let msg = BoxVoIPCallOfferMessage()
        msg.jsonData = "{type: 'call offer'}".data(using: .utf8)
        
        let result = MessageDecoder.decode(MSGTYPE_VOIP_CALL_OFFER, body: msg.body()) as? BoxVoIPCallOfferMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.jsonData, msg.jsonData)
    }
    
    func testDecodeBoxVoIPCallRingingMessage() {
        let msg = Data()
        
        let result = MessageDecoder.decode(MSGTYPE_VOIP_CALL_RINGING, body: msg) as? BoxVoIPCallRingingMessage
        
        XCTAssertNotNil(result)
    }
    
    func testDecodeContactDeletePhotoMessage() {
        let msg = Data()
        
        let result = MessageDecoder.decode(MSGTYPE_CONTACT_DELETE_PHOTO, body: msg) as? ContactDeletePhotoMessage
        
        XCTAssertNotNil(result)
    }
    
    func testDecodeContactRequestPhotoMessage() {
        let msg = Data()
        
        let result = MessageDecoder.decode(MSGTYPE_CONTACT_REQUEST_PHOTO, body: msg) as? ContactRequestPhotoMessage
        
        XCTAssertNotNil(result)
    }
    
    func testDecodeContactSetPhotoMessage() {
        let msg = ContactSetPhotoMessage()
        msg.blobID = Data(BytesUtility.padding([], pad: 0x68, length: ThreemaProtocol.blobIDLength))
        msg.size = 10
        msg.encryptionKey = Data(BytesUtility.padding([], pad: 0x91, length: Int(kBlobKeyLen)))
        
        let result = MessageDecoder.decode(MSGTYPE_CONTACT_SET_PHOTO, body: msg.body()) as? ContactSetPhotoMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.blobID, msg.blobID)
        XCTAssertEqual(result?.size, msg.size)
        XCTAssertEqual(result?.encryptionKey, msg.encryptionKey)
    }
    
    func testDecodeGroupAudioMessage() {
        let msg = GroupAudioMessage()
        msg.groupCreator = "TESTID12"
        msg.groupID = Data(BytesUtility.padding([], pad: 0x67, length: ThreemaProtocol.groupIDLength))
        msg.duration = 1
        msg.audioBlobID = Data(BytesUtility.padding([], pad: 0x03, length: ThreemaProtocol.blobIDLength))
        msg.audioSize = 10
        msg.encryptionKey = Data(BytesUtility.padding([], pad: 0x04, length: Int(kBlobKeyLen)))

        let result = MessageDecoder.decode(MSGTYPE_GROUP_AUDIO, body: msg.body()) as? GroupAudioMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupCreator, msg.groupCreator)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.duration, msg.duration)
        XCTAssertEqual(result?.audioBlobID, msg.audioBlobID)
        XCTAssertEqual(result?.audioSize, msg.audioSize)
        XCTAssertEqual(result?.encryptionKey, msg.encryptionKey)
    }
    
    func testDecodeGroupBallotCreateMessage() {
        let msg = GroupBallotCreateMessage()
        msg.groupCreator = "TESTID12"
        msg.groupID = Data(BytesUtility.padding([], pad: 0x11, length: ThreemaProtocol.groupIDLength))
        msg.ballotID = Data(BytesUtility.padding([], pad: 0x22, length: ThreemaProtocol.ballotIDLength))
        msg.jsonData = "{type: 'group ballot create'}".data(using: .utf8)
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_BALLOT_CREATE, body: msg.body()) as? GroupBallotCreateMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupCreator, msg.groupCreator)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.ballotID, msg.ballotID)
        XCTAssertEqual(result?.jsonData, msg.jsonData)
    }
    
    func testDecodeGroupBallotVoteMessage() {
        let msg = GroupBallotVoteMessage()
        msg.groupCreator = "TESTID12"
        msg.groupID = Data(BytesUtility.padding([], pad: 0x66, length: ThreemaProtocol.groupIDLength))
        msg.ballotCreator = "TESTID34"
        msg.ballotID = Data(BytesUtility.padding([], pad: 0x55, length: ThreemaProtocol.ballotIDLength))
        msg.jsonChoiceData = "{type: 'group ballot vote'}".data(using: .utf8)
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_BALLOT_VOTE, body: msg.body()) as? GroupBallotVoteMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupCreator, msg.groupCreator)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.ballotCreator, msg.ballotCreator)
        XCTAssertEqual(result?.ballotID, msg.ballotID)
        XCTAssertEqual(result?.jsonChoiceData, msg.jsonChoiceData)
    }
    
    func testDecodeGroupCreateMessage() {
        let msg = GroupCreateMessage()
        msg.groupID = Data(BytesUtility.padding([], pad: 0x09, length: ThreemaProtocol.groupIDLength))
        msg.groupMembers = ["ECHOECHO"]
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_CREATE, body: msg.body()) as? GroupCreateMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.groupMembers.count, 1)
        XCTAssertEqual(result?.groupMembers[0] as? String, "ECHOECHO")
    }
    
    func testDecodeGroupDeletePhotoMessage() {
        let msg = GroupDeletePhotoMessage()
        msg.groupID = Data(BytesUtility.padding([], pad: 0x13, length: ThreemaProtocol.groupIDLength))
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_DELETE_PHOTO, body: msg.body()) as? GroupDeletePhotoMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupID, msg.groupID)
    }
    
    func testDecodeGroupDeliveryReceiptMessage() {
        let msg = GroupDeliveryReceiptMessage()
        msg.groupID = Data(BytesUtility.padding([], pad: 0x13, length: ThreemaProtocol.groupIDLength))
        msg.groupCreator = "TESTID12"
        msg.receiptMessageIDs = [Data(BytesUtility.padding([], pad: 0xEF, length: ThreemaProtocol.messageIDLength))]
        msg.receiptType = ReceiptType.read.rawValue
        
        let result = MessageDecoder.decode(
            MSGTYPE_GROUP_DELIVERY_RECEIPT,
            body: msg.body()
        ) as? GroupDeliveryReceiptMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupCreator, msg.groupCreator)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.receiptMessageIDs.count, 1)
        XCTAssertEqual(result?.receiptType, msg.receiptType)
    }
    
    func testDecodeGroupFileMessage() {
        let msg = GroupFileMessage()
        msg.groupCreator = "TESTID12"
        msg.groupID = Data(BytesUtility.padding([], pad: 0x46, length: ThreemaProtocol.groupIDLength))
        msg.jsonData = "{type: 'group file'}".data(using: .utf8)
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_FILE, body: msg.body()) as? GroupFileMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupCreator, msg.groupCreator)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.jsonData, msg.jsonData)
    }
    
    func testDecodeGroupImageMessage() {
        let msg = GroupImageMessage()
        msg.groupCreator = "TESTID12"
        msg.groupID = Data(BytesUtility.padding([], pad: 0x23, length: ThreemaProtocol.groupIDLength))
        msg.blobID = Data(BytesUtility.padding([], pad: 0x01, length: ThreemaProtocol.blobIDLength))
        msg.size = 3
        msg.encryptionKey = Data(BytesUtility.padding([], pad: 0x03, length: Int(kBlobKeyLen)))
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_IMAGE, body: msg.body()) as? GroupImageMessage

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupCreator, msg.groupCreator)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.blobID, msg.blobID)
        XCTAssertEqual(result?.size, msg.size)
        XCTAssertEqual(result?.encryptionKey, msg.encryptionKey)
    }
    
    func testDecodeGroupLeaveMessage() {
        let msg = GroupLeaveMessage()
        msg.groupID = Data(BytesUtility.padding([], pad: 0x54, length: ThreemaProtocol.groupIDLength))
        msg.groupCreator = "TESTID12"
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_LEAVE, body: msg.body()) as? GroupLeaveMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.groupCreator, msg.groupCreator)
    }
    
    func testDecodeGroupLocationMessage() {
        var msg: Data = "TESTID12".data(using: .utf8)!
        let groupID = Data(BytesUtility.padding([], pad: 0x12, length: ThreemaProtocol.groupIDLength))
        msg.append(groupID)
        msg.append("47.201515,8.783403,65.000000".data(using: .utf8)!)

        let result = MessageDecoder.decode(MSGTYPE_GROUP_LOCATION, body: msg) as? GroupLocationMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupID, groupID)
        XCTAssertEqual(result?.groupCreator, "TESTID12")
        XCTAssertEqual(result?.latitude, 47.201515)
        XCTAssertEqual(result?.longitude, 8.783403)
        XCTAssertEqual(result?.accuracy, 65.000000)
    }
    
    func testDecodeGroupRenameMessage() {
        let msg = GroupRenameMessage()
        msg.groupID = Data(BytesUtility.padding([], pad: 0x69, length: ThreemaProtocol.groupIDLength))
        msg.name = "Group name"
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_RENAME, body: msg.body()) as? GroupRenameMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.name, msg.name)
    }
    
    func testDecodeGroupRequestSyncMessage() {
        let msg = GroupRequestSyncMessage()
        msg.groupCreator = "TESTID12"
        msg.groupID = Data(BytesUtility.padding([], pad: 0x77, length: ThreemaProtocol.groupIDLength))
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_REQUEST_SYNC, body: msg.body()) as? GroupRequestSyncMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupID, msg.groupID)
    }
    
    func testDecodeGroupSetPhotoMessage() {
        let msg = GroupSetPhotoMessage()
        msg.groupID = Data(BytesUtility.padding([], pad: 0x50, length: ThreemaProtocol.groupIDLength))
        msg.blobID = Data(BytesUtility.padding([], pad: 0x60, length: ThreemaProtocol.blobIDLength))
        msg.size = 4
        msg.encryptionKey = Data(BytesUtility.padding([], pad: 0x70, length: Int(kBlobKeyLen)))
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_SET_PHOTO, body: msg.body()) as? GroupSetPhotoMessage
        
        XCTAssertNotNil(result)
    }
    
    func testDecodeGroupTextMessage() throws {
        let msg = GroupTextMessage()
        msg.groupID = Data(BytesUtility.padding([], pad: 0x34, length: ThreemaProtocol.groupIDLength))
        msg.groupCreator = "TESTID12"
        msg.text = "Test text"
        
        let result = MessageDecoder.decode(MSGTYPE_GROUP_TEXT, body: msg.body()) as? GroupTextMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.groupCreator, msg.groupCreator)
        XCTAssertEqual(result?.text, msg.text)
        XCTAssertNil(result?.quotedMessageID)
        XCTAssertEqual(
            try String(data: XCTUnwrap(result?.quotedBody()), encoding: .utf8),
            "TESTID1244444444Test text"
        )
    }
    
    func testDecodeGroupTextMessageQuoted() throws {
        let expectedQuotedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)
        let expectedQuotedText = QuoteUtil.generateText("Test text", with: expectedQuotedMessageID)!

        let msg = GroupTextMessage()
        msg.groupID = Data(BytesUtility.padding([], pad: 0x34, length: ThreemaProtocol.groupIDLength))
        msg.groupCreator = "TESTID12"
        msg.text = expectedQuotedText

        let result = MessageDecoder.decode(MSGTYPE_GROUP_TEXT, body: msg.body()) as? GroupTextMessage

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.groupCreator, msg.groupCreator)
        XCTAssertEqual(result?.text, "Test text")
        XCTAssertEqual(result?.quotedMessageID, expectedQuotedMessageID)
        XCTAssertEqual(
            try String(data: XCTUnwrap((XCTUnwrap(result) as QuotedMessageProtocol).quotedBody()), encoding: .utf8),
            "TESTID1244444444\(expectedQuotedText)"
        )
    }

    func testDecodeGroupVideoMessage() {
        let msg = GroupVideoMessage()
        msg.groupCreator = "TESTID12"
        msg.groupID = Data(BytesUtility.padding([], pad: 0x56, length: ThreemaProtocol.groupIDLength))
        msg.duration = 1
        msg.encryptionKey = Data(BytesUtility.padding([], pad: 0x02, length: Int(kBlobKeyLen)))
        msg.thumbnailBlobID = Data(BytesUtility.padding([], pad: 0x03, length: ThreemaProtocol.blobIDLength))
        msg.thumbnailSize = 3
        msg.videoBlobID = Data(BytesUtility.padding([], pad: 0x04, length: ThreemaProtocol.blobIDLength))
        msg.videoSize = 2

        let result = MessageDecoder.decode(MSGTYPE_GROUP_VIDEO, body: msg.body()) as? GroupVideoMessage
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.groupCreator, msg.groupCreator)
        XCTAssertEqual(result?.groupID, msg.groupID)
        XCTAssertEqual(result?.duration, msg.duration)
        XCTAssertEqual(result?.encryptionKey, msg.encryptionKey)
        XCTAssertEqual(result?.thumbnailBlobID, msg.thumbnailBlobID)
        XCTAssertEqual(result?.thumbnailSize, msg.thumbnailSize)
        XCTAssertEqual(result?.videoBlobID, msg.videoBlobID)
        XCTAssertEqual(result?.videoSize, msg.videoSize)
    }
    
    func testDecodeTypingIndicatorMessage() {
        let msg = TypingIndicatorMessage()
        msg.typing = true
        
        let result = MessageDecoder.decode(MSGTYPE_TYPING_INDICATOR, body: msg.body()) as? TypingIndicatorMessage
        
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.typing)
    }
    
    private func parseJson(_ obj: Any) -> Data? {
        do {
            return try JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted)
        }
        catch {
            XCTFail("Can't build json")
            return nil
        }
    }
    
    private func newBoxBallotCreateMessage(_ obj: Any) -> BoxBallotCreateMessage {
        let msg = BoxBallotCreateMessage()
        msg.ballotID = Data(BytesUtility.padding([], pad: 0x88, length: ThreemaProtocol.ballotIDLength))
        msg.jsonData = parseJson(obj)
        return msg
    }
    
    private func checkBallotResult(ballotMessage: BallotMessage?, result: [Any]) {
        let allObjects = ((ballotMessage?.ballot.choices)! as NSSet).allObjects
        let choice1 = allObjects.first as! BallotChoice
        let choice2 = allObjects.last as! BallotChoice
        
        if choice1.orderPosition == 0 {
            XCTAssertEqual(choice1.name, result[0] as? String)
            XCTAssertEqual(choice2.name, result[1] as? String)
        }
        else {
            XCTAssertEqual(choice1.name, result[1] as? String)
            XCTAssertEqual(choice2.name, result[0] as? String)
        }
    }
}
