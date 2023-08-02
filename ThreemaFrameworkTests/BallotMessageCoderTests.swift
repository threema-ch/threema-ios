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
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversation(for: Data([1]), creator: "ECHOECHO"))
        
        // Create Ballot
        let ballot = createLocalBallot()
        ballot.addChoices(createChoices())
        ballot.ballotDisplayMode = .summary
        
        // Act:
        // Encode:
        let boxBallotCreateMessage = BallotMessageEncoder.encodeCreateMessage(for: ballot)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"

        // Decode:
        let ballotMessage = ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation
        )
        let decodedBallot = ballotMessage?.ballot
        
        // Assert:
        XCTAssertEqual(decodedBallot?.ballotDisplayMode, BallotDisplayMode.summary)
    }
    
    func testBallotEncodingDisplayModeNotSpecified() throws {
        // Goal: Test that DisplayMode is List, when nothing is specified
        
        // Arrange:
        let entityManager = EntityManager(databaseContext: dBContext)
        let ballotDecoder = BallotMessageDecoder(entityManager)
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversation(for: Data([1]), creator: "ECHOECHO"))
        
        // Create Ballot
        let ballot = createLocalBallot()
        ballot.addChoices(createChoices())
        
        // Act:
        // Encode:
        let boxBallotCreateMessage = BallotMessageEncoder.encodeCreateMessage(for: ballot)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"

        // Decode:
        let ballotMessage = ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation
        )
        let decodedBallot = ballotMessage?.ballot
        
        // Assert:
        XCTAssertEqual(decodedBallot?.ballotDisplayMode, BallotDisplayMode.list)
    }
    
    func testBallotEncodingChoicesTotalVotesNotSet() throws {
        // Goal: Test that Choices have no value for totalVotes after Encoding
        
        // Arrange:
        let entityManager = EntityManager(databaseContext: dBContext)
        let ballotDecoder = BallotMessageDecoder(entityManager)
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversation(for: Data([1]), creator: "ECHOECHO"))
        
        // Create Ballot
        let ballot = createLocalBallot()
        ballot.addChoices(createChoices())
        
        // Act:
        // Add TotalVotes to Choices
        for choice in ballot.choices {
            guard let choice = choice as? BallotChoice else {
                XCTFail("Choice must be BallotChoice")
                return
            }
            choice.totalVotes = NSNumber(integerLiteral: Int.random(in: 0...100))
        }
        // Encode:
        let boxBallotCreateMessage = BallotMessageEncoder.encodeCreateMessage(for: ballot)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"
        entityManager.entityDestroyer.deleteObject(object: ballot)
        
        // Decode:
        let ballotMessage = ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation
        )
        let decodedBallot = ballotMessage?.ballot
        
        // Assert:
        for choice in decodedBallot!.choices {
            guard let choice = choice as? BallotChoice else {
                XCTFail("Choice must be BallotChoice")
                return
            }
            XCTAssertEqual(choice.totalVotes, nil)
        }
    }
    
    // MARK: - Decoding
    
    func testDecodeMessageCreateBallot() throws {
        // Goal: Test Decoding of incoming message without existing Ballot
        // Arrange:
        let entityManager = EntityManager(databaseContext: dBContext)
        let ballotDecoder = BallotMessageDecoder(entityManager)
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversation(for: Data([1]), creator: "ECHOECHO"))
        let boxBallotCreateMessage = BoxBallotCreateMessage()
        let jsonString = preparer.loadContentAsString(
            "BallotCoderTests_testDecodeMessageCreateBallot",
            fileExtension: "json"
        )
        boxBallotCreateMessage.ballotID = "BMD_1".data(using: String.Encoding.ascii)
        boxBallotCreateMessage.jsonData = jsonString?.data(using: String.Encoding.utf8)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"
        
        // Act:
        let ballotMessage = ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation
        )
        let ballot = ballotMessage?.ballot
        guard let choices = ballot?.choicesSortedByOrder() as? [BallotChoice] else {
            XCTFail("Could not decode choices")
            return
        }
        let choice0 = choices[0]
        let choice1 = choices[1]
        let results0: [BallotResult] = (Array(choice0.result) as? [BallotResult])!
        let results1: [BallotResult] = (Array(choice1.result) as? [BallotResult])!
        
        // Assert:
        // Ballot
        XCTAssertEqual(ballot?.title, "Test Ballot ListMode")
        XCTAssertEqual(ballot?.state, 0)
        XCTAssertEqual(ballot?.assessmentType, 1)
        XCTAssertEqual(ballot?.type, 1)
        XCTAssertEqual(ballot?.choicesType, 0)
        XCTAssertEqual(ballot?.ballotDisplayMode, .list)
        
        // Choices
        XCTAssertEqual(choices.count, 4)
        // Choice 0
        XCTAssertEqual(choice0.id, 1)
        XCTAssertEqual(choice0.name, "desc1")
        XCTAssertEqual(choice0.orderPosition, 1)
        XCTAssertEqual(choice0.totalVotes, nil)
        XCTAssertEqual(results0.count, 3)
        
        for result in results0 {
            switch result.participantID {
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
            switch result.participantID {
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
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversation(for: Data([1]), creator: "ECHOECHO"))
        let boxBallotCreateMessage = BoxBallotCreateMessage()
        let jsonString = preparer.loadContentAsString(
            "BallotCoderTests_testDecodeMessageCreateNoResult",
            fileExtension: "json"
        )
        boxBallotCreateMessage.ballotID = "BMD_1".data(using: String.Encoding.ascii)
        boxBallotCreateMessage.jsonData = jsonString?.data(using: String.Encoding.utf8)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"
        
        // Act:
        let ballotMessage = ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation
        )
        let ballot = ballotMessage?.ballot
        guard let choices = ballot?.choicesSortedByOrder() as? [BallotChoice] else {
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
        // Goal: If incoming ballot has summary display mode, its choices must have values for totalVotes, no values for participants and no values for participants votes
        
        // Arrange:
        let entityManager = EntityManager(databaseContext: dBContext)
        let ballotDecoder = BallotMessageDecoder(entityManager)
        let conversation = try XCTUnwrap(entityManager.entityFetcher.conversation(for: Data([1]), creator: "ECHOECHO"))
        let boxBallotCreateMessage = BoxBallotCreateMessage()
        let jsonString = preparer.loadContentAsString(
            "BallotCoderTests_testDecodeMessageSummaryModeSetsTotalVotesOfChoices",
            fileExtension: "json"
        )
        boxBallotCreateMessage.ballotID = "BMD_1".data(using: String.Encoding.ascii)
        boxBallotCreateMessage.jsonData = jsonString?.data(using: String.Encoding.utf8)
        boxBallotCreateMessage.fromIdentity = "ECHOECHO"
        
        // Act:
        let ballotMessage = ballotDecoder?.decodeCreateBallot(
            fromBox: boxBallotCreateMessage,
            sender: nil,
            conversation: conversation
        )
        let ballot = ballotMessage?.ballot
        guard let choices = ballot?.choicesSortedByOrder() as? [BallotChoice] else {
            XCTFail("Could not decode choices")
            return
        }
        let choice0 = choices[0]
        let choice1 = choices[1]
        let choice2 = choices[2]
        let choice3 = choices[3]
        
        let results0: [BallotResult] = (Array(choice0.result) as? [BallotResult])!
        let results1: [BallotResult] = (Array(choice0.result) as? [BallotResult])!
        let results2: [BallotResult] = (Array(choice0.result) as? [BallotResult])!
        let results3: [BallotResult] = (Array(choice0.result) as? [BallotResult])!

        // Assert:
        XCTAssertEqual(ballot?.participants.isEmpty, true)
        
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
    
    private func createLocalBallot() -> Ballot {
        let ballot = Ballot(context: preparer.objectContext)
        ballot.id = Data(base64Encoded: "TestID")
        ballot.createDate = Date()
        ballot.creatorID = "MyID"
        ballot.title = "TestBallot"
        ballot.state = 0
        ballot.assessmentType = 0
        ballot.choicesType = 0
        
        return ballot
    }
    
    private func createChoices() -> Set<BallotChoice> {
        var choices = Set<BallotChoice>()
        for i in 0..<3 {
            let choice = BallotChoice(context: preparer.objectContext)
            choice.id = NSNumber(integerLiteral: i)
            choice.name = "Choice \(i)"
            choice.orderPosition = NSNumber(integerLiteral: i)
            choices.insert(choice)
        }
        return choices
    }
}
