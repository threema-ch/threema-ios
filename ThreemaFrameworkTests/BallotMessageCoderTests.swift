//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

class BallotMessageCoderTests: XCTestCase {
    let preparer = BallotMessagePreparer()
    lazy var dBContext = DatabaseContext(mainContext: preparer.objectContext, backgroundContext: nil)
    
    // MARK: Setup & TearDown
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        // Prepare a DB before each Test
        preparer.prepareDatabase()
    }
    
    override func tearDownWithError() throws { }
    
    // MARK: - Tests
    
    // MARK: - Encoding
    
    func testBallotEncodingDisplayModeSummary() throws {
        // Goal: Test impossibility for client to create a Ballot with DisplayModeSummary
        
        // Arrange:
        let entityManager = EntityManager(databaseContext: dBContext)
        let ballotDecoder = BallotMessageDecoder(entityManager)
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversationEntity(
            for: Data([1]),
            creator: "ECHOECHO"
        ))
        
        // Create Ballot
        let ballot = createLocalBallot()
        createChoices(for: ballot)
        ballot.displayMode = NSNumber(integerLiteral: BallotDisplayMode.summary.rawValue)
        
        // Act:
        // Encode:
        let boxBallotCreateMessage = BallotMessageEncoder.encodeCreateMessage(forBallot: ballot)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"

        // Decode:
        let expect = expectation(description: "Decode and create ballot")

        var decodedBallot: BallotEntity?
        ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation,
            onCompletion: { message in
                decodedBallot = message.ballot
                expect.fulfill()
            },
            onError: { error in
                XCTFail("\(error)")
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 3)

        // Assert:
        XCTAssertEqual(decodedBallot?.displayMode?.intValue, BallotDisplayMode.summary.rawValue)
    }
    
    func testBallotEncodingDisplayModeNotSpecified() throws {
        // Goal: Test that DisplayMode is List, when nothing is specified

        // Arrange:
        let entityManager = EntityManager(databaseContext: dBContext)
        let ballotDecoder = BallotMessageDecoder(entityManager)
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversationEntity(
            for: Data([1]),
            creator:
            "ECHOECHO"
        ))

        // Create Ballot
        let ballot = createLocalBallot()
        createChoices(for: ballot)

        // Act:
        // Encode:
        let boxBallotCreateMessage = BallotMessageEncoder.encodeCreateMessage(forBallot: ballot)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"

        // Decode:
        let expect = expectation(description: "Decode and create ballot")

        var decodedBallot: BallotEntity?
        ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation,
            onCompletion: { message in
                decodedBallot = message.ballot
                expect.fulfill()
            },
            onError: { error in
                XCTFail("\(error)")
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 3)

        // Assert:
        XCTAssertEqual(decodedBallot?.displayMode?.intValue, BallotDisplayMode.list.rawValue)
    }

    func testBallotEncodingChoicesTotalVotesNotSet() throws {
        // Goal: Test that Choices have no value for totalVotes after Encoding

        // Arrange:
        let entityManager = EntityManager(databaseContext: dBContext)
        let ballotDecoder = BallotMessageDecoder(entityManager)
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversationEntity(
            for: Data([1]),
            creator:
            "ECHOECHO"
        ))

        // Create Ballot
        let ballot = createLocalBallot()
        createChoices(for: ballot)

        // Act:
        // Add TotalVotes to Choices
        for choice in ballot.choices! {
            choice.totalVotes = NSNumber(integerLiteral: Int.random(in: 0...100))
        }
        
        // Encode:
        let boxBallotCreateMessage = BallotMessageEncoder.encodeCreateMessage(forBallot: ballot)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"
        boxBallotCreateMessage.ballotID = ballot.id
        
        entityManager.entityDestroyer.delete(ballot: ballot)

        // Decode:
        let expect = expectation(description: "Decode and create ballot")

        var decodedBallot: BallotEntity?
        ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation,
            onCompletion: { message in
                decodedBallot = message.ballot
                expect.fulfill()
            },
            onError: { error in
                XCTFail("\(error)")
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 3)

        // Assert:
        for choice in try XCTUnwrap(decodedBallot?.choices) {
            XCTAssertEqual(choice.totalVotes, nil)
        }
    }

    // MARK: - Decoding

    func testDecodeMessageCreateBallot() throws {
        // Goal: Test Decoding of incoming message without existing Ballot
        // Arrange:
        let entityManager = EntityManager(databaseContext: dBContext)
        let ballotDecoder = BallotMessageDecoder(entityManager)
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversationEntity(
            for: Data([1]),
            creator:
            "ECHOECHO"
        ))
        let boxBallotCreateMessage = BoxBallotCreateMessage()
        let jsonString = preparer.loadContentAsString(
            "BallotCoderTests_testDecodeMessageCreateBallot",
            fileExtension: "json"
        )
        boxBallotCreateMessage.ballotID = "BMD_1".data(using: String.Encoding.ascii)
        boxBallotCreateMessage.jsonData = jsonString?.data(using: String.Encoding.utf8)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"

        // Act:
        let expect = expectation(description: "Decode and create ballot")

        var decodedBallot: BallotEntity?
        ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation,
            onCompletion: { message in
                decodedBallot = message.ballot
                expect.fulfill()
            },
            onError: { error in
                XCTFail("\(error)")
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 3)

        guard let choices = decodedBallot?.choicesSortedByOrder as? [BallotChoiceEntity] else {
            XCTFail("Could not decode choices")
            return
        }
        let choice0 = choices[0]
        let choice1 = choices[1]
        let results0: [BallotResultEntity] = (Array(choice0.result!) as? [BallotResultEntity])!
        let results1: [BallotResultEntity] = (Array(choice1.result!) as? [BallotResultEntity])!

        // Assert:
        // Ballot
        XCTAssertEqual(decodedBallot?.title, "Test Ballot ListMode")
        XCTAssertEqual(decodedBallot?.state, 0)
        XCTAssertEqual(decodedBallot?.assessmentType, 1)
        XCTAssertEqual(decodedBallot?.type, 1)
        XCTAssertEqual(decodedBallot?.choicesType, 0)
        XCTAssertEqual(decodedBallot?.displayMode?.intValue, BallotDisplayMode.list.rawValue)

        // Choices
        XCTAssertEqual(choices.count, 4)
        // Choice 0
        XCTAssertEqual(choice0.id, 1)
        XCTAssertEqual(choice0.name, "desc1")
        XCTAssertEqual(choice0.orderPosition, 1)
        XCTAssertEqual(choice0.totalVotes, nil)
        XCTAssertEqual(results0.count, 3)

        for result in results0 {
            // swiftformat:disable:next acronyms
            switch result.participantId {
            case "ECHOECHO":
                XCTAssertEqual(result.value, 1)
            case "ECHOECHO1":
                XCTAssertEqual(result.value, 0)
            case "ECHOECHO2":
                XCTAssertEqual(result.value, 0)
            default:
                XCTFail("Unexpected Participant Id")
            }
        }

        // Choice 1
        XCTAssertEqual(choice1.id, 2)
        XCTAssertEqual(choice1.name, "desc2")
        XCTAssertEqual(choice1.orderPosition, 2)
        XCTAssertEqual(choice1.totalVotes, nil)
        XCTAssertEqual(results1.count, 3)

        for result in results1 {
            // swiftformat:disable:next acronyms
            switch result.participantId {
            case "ECHOECHO":
                XCTAssertEqual(result.value, 1)
            case "ECHOECHO1":
                XCTAssertEqual(result.value, 1)
            case "ECHOECHO2":
                XCTAssertEqual(result.value, 1)
            default:
                XCTFail("Unexpected Participant Id")
            }
        }
    }

    func testDecodeMessageCreateNoResult() throws {
        // Goal: Creating a message with no results must not crash

        // Arrange:
        let entityManager = EntityManager(databaseContext: dBContext)
        let ballotDecoder = BallotMessageDecoder(entityManager)
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversationEntity(
            for: Data([1]),
            creator:
            "ECHOECHO"
        ))
        let boxBallotCreateMessage = BoxBallotCreateMessage()
        let jsonString = preparer.loadContentAsString(
            "BallotCoderTests_testDecodeMessageCreateNoResult",
            fileExtension: "json"
        )
        boxBallotCreateMessage.ballotID = "BMD_1".data(using: String.Encoding.ascii)
        boxBallotCreateMessage.jsonData = jsonString?.data(using: String.Encoding.utf8)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"

        // Act:
        let expect = expectation(description: "Decode and create ballot")

        var decodedBallot: BallotEntity?
        ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation,
            onCompletion: { message in
                decodedBallot = message.ballot
                expect.fulfill()
            },
            onError: { error in
                XCTFail("\(error)")
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 3)

        guard let choices = decodedBallot?.choicesSortedByOrder as? [BallotChoiceEntity] else {
            XCTFail("Could not decode choices")
            return
        }
        let choice0 = choices[0]
        let choice1 = choices[1]

        // Assert:
        XCTAssertEqual(choice0.id, 1)
        XCTAssertEqual(choice0.name, "desc1")
        XCTAssertEqual(choice0.orderPosition, 1)

        XCTAssertEqual(choice1.id, 2)
        XCTAssertEqual(choice1.name, "desc2")
        XCTAssertEqual(choice1.orderPosition, 2)
    }

    func testDecodeMessageSummaryModeSetsTotalVotesOfChoices() throws {
        // Goal: If incoming ballot has summary display mode, its choices must have values for totalVotes, no values
        // for participants and no values for participants votes

        // Arrange:
        let entityManager = EntityManager(databaseContext: dBContext)
        let ballotDecoder = BallotMessageDecoder(entityManager)
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversationEntity(
            for: Data([1]),
            creator:
            "ECHOECHO"
        ))
        let boxBallotCreateMessage = BoxBallotCreateMessage()
        let jsonString = preparer.loadContentAsString(
            "BallotCoderTests_testDecodeMessageSummaryModeSetsTotalVotesOfChoices",
            fileExtension: "json"
        )
        boxBallotCreateMessage.ballotID = "BMD_1".data(using: String.Encoding.ascii)
        boxBallotCreateMessage.jsonData = jsonString?.data(using: String.Encoding.utf8)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"

        // Act:
        let expect = expectation(description: "Decode and create ballot")

        var decodedBallot: BallotEntity?
        ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation,
            onCompletion: { message in
                decodedBallot = message.ballot
                expect.fulfill()
            },
            onError: { error in
                XCTFail("\(error)")
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 3)

        guard let choices = decodedBallot?.choicesSortedByOrder as? [BallotChoiceEntity] else {
            XCTFail("Could not decode choices")
            return
        }
        let choice0 = choices[0]
        let choice1 = choices[1]
        let choice2 = choices[2]
        let choice3 = choices[3]

        let results0: [BallotResultEntity] = (Array(choice0.result!) as? [BallotResultEntity])!
        let results1: [BallotResultEntity] = (Array(choice0.result!) as? [BallotResultEntity])!
        let results2: [BallotResultEntity] = (Array(choice0.result!) as? [BallotResultEntity])!
        let results3: [BallotResultEntity] = (Array(choice0.result!) as? [BallotResultEntity])!

        // Assert:
        XCTAssertEqual(decodedBallot?.participants?.isEmpty, true)

        XCTAssertEqual(choice0.totalVotes, 500)
        XCTAssertEqual(choice1.totalVotes, 100)
        XCTAssertEqual(choice2.totalVotes, 0)
        XCTAssertEqual(choice3.totalVotes, 1)

        XCTAssertEqual(results0.isEmpty, true)
        XCTAssertEqual(results1.isEmpty, true)
        XCTAssertEqual(results2.isEmpty, true)
        XCTAssertEqual(results3.isEmpty, true)
    }
    
    // MARK: - Functions
    
    private func createLocalBallot() -> BallotEntity {
        let ballot = BallotEntity(
            context: preparer.objectContext,
            assessmentType: .single,
            id: MockData.generateBallotID(),
            state: .open,
            type: .closed
        )
        ballot.id = MockData.generateBallotID()
        ballot.createDate = Date()
        // swiftformat:disable:next acronyms
        ballot.creatorId = "MyID"
        ballot.title = "TestBallot"
        ballot.choicesType = 0
        
        return ballot
    }
    
    private func createChoices(for ballot: BallotEntity) {
        for i in 0..<3 {
            let choice = BallotChoiceEntity(
                context: preparer.objectContext,
                id: NSNumber(integerLiteral: i),
                ballot: ballot
            )
            choice.name = "Choice \(i)"
            choice.orderPosition = NSNumber(integerLiteral: i)
        }
    }
}
