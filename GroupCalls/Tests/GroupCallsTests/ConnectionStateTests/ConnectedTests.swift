//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
import Foundation
import ThreemaEssentials
import ThreemaProtocols
import XCTest
@testable import GroupCalls

final class ConnectedTests: XCTestCase {
    
    fileprivate lazy var creatorIdentity = ThreemaIdentity("ECHOECHO")
    fileprivate lazy var groupIdentity = GroupIdentity(id: Data(repeating: 0x00, count: 8), creator: creatorIdentity)
    fileprivate lazy var localContactModel = ContactModel(identity: creatorIdentity, nickname: "ECHOECHO")
    fileprivate lazy var groupModel = GroupCallThreemaGroupModel(groupIdentity: groupIdentity, groupName: "TESTGROUP")
    fileprivate lazy var sfuBaseURL = URL(string: "sfu.threema.test")!
    fileprivate lazy var gck = Data(repeating: 0x01, count: 32)

    // MARK: - Test cases
    
    /// Tests a basic initialization of `Connected`
    @GlobalGroupCallActor
    func testBasicInit() async throws {
        let dependencies = MockDependencies().create()
        
        let groupCallActor = try GroupCallActor(
            localContactModel: localContactModel,
            groupModel: groupModel,
            sfuBaseURL: sfuBaseURL,
            gck: gck,
            dependencies: dependencies
        )
        
        let groupCallStartData = GroupCallStartData(
            protocolVersion: 0,
            gck: gck,
            sfuBaseURL: sfuBaseURL
        )
        
        let groupCallMessageCrypto = try GroupCallBaseState(
            group: groupModel,
            startedAt: .now,
            dependencies: dependencies,
            groupCallStartData: groupCallStartData
        )
        
        let groupCallContext = MockGroupCallContext(
            dependencies: dependencies,
            groupCallMessageCrypto: groupCallMessageCrypto
        )
        
        Connected(
            groupCallActor: groupCallActor,
            groupCallContext: groupCallContext,
            participantIDs: [UInt32]()
        )
    }
    
    /// Tests the correct passing of `PeerConnectionMessage`'s in the process loop in `next()`
    @GlobalGroupCallActor
    func testConnectedProcessBuffer() async throws {
        // Arrange
        let dependencies = MockDependencies().create()
        
        let groupCallActor = try GroupCallActor(
            localContactModel: localContactModel,
            groupModel: groupModel,
            sfuBaseURL: sfuBaseURL,
            gck: gck,
            dependencies: dependencies
        )
        
        let groupCallStartData = GroupCallStartData(
            protocolVersion: 0,
            gck: gck,
            sfuBaseURL: sfuBaseURL
        )
        
        let groupCallMessageCrypto = try! GroupCallBaseState(
            group: groupModel,
            startedAt: .now,
            dependencies: dependencies,
            groupCallStartData: groupCallStartData
        )
        
        let groupCallContext = MockGroupCallContext(
            dependencies: dependencies,
            groupCallMessageCrypto: groupCallMessageCrypto
        )
        
        let connected = Connected(
            groupCallActor: groupCallActor,
            groupCallContext: groupCallContext,
            participantIDs: [UInt32]()
        )
        
        let expectation = XCTestExpectation(description: "Connected next() completed.")
       
        // Act
        Task.detached {
            let newState = try await connected.next()
            XCTAssertTrue(newState is Ending)
            expectation.fulfill()
        }
        
        try groupCallContext.continuation.yield(PeerConnectionMessage(data: joinMessage(for: 1)))
        
        try groupCallContext.continuation.yield(PeerConnectionMessage(data: relayMessage()))
        
        Task.detached {
            // We sleep for one sec so the yields above can be processed.
            try await Task.sleep(seconds: 1)
            // To break the process loop in the next(), we force leave.
            await groupCallActor.forceLeaveCall()
        }
        
        await fulfillment(of: [expectation])
        
        // Assert
        
        // There is always one call before the processing loop starts and then there is another one for each participant
        // that joins or leaves
        XCTAssertEqual(groupCallContext.updateParticipantCount, 2)
        XCTAssertEqual(groupCallContext.handleCallCount, 1)
    }
    
    // TODO: (IOS-3880) Add tests to verify the correct handling of `GroupCallUIAction`s
    
    // MARK: - Helper Functions
    
    private func joinMessage(for id: UInt32) throws -> Data {
        var participantJoined = Groupcall_SfuToParticipant.ParticipantJoined()
        participantJoined.participantID = id
        
        var envelope = Groupcall_SfuToParticipant.Envelope()
        envelope.participantJoined = participantJoined
        
        return try envelope.ownSerializedData()
    }
    
    private func relayMessage() throws -> Data {
        let hello = Groupcall_ParticipantToParticipant.Handshake.Hello()
        
        var envelope = Groupcall_ParticipantToParticipant.Handshake.HelloEnvelope()
        envelope.hello = hello
        
        return try envelope.ownSerializedData()
    }
}
