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
    
    fileprivate var closed = false
    fileprivate lazy var creatorIdentity = ThreemaIdentity("ECHOECHO")
    fileprivate lazy var groupIdentity = GroupIdentity(id: Data(repeating: 0x00, count: 8), creator: creatorIdentity)
    fileprivate lazy var localContactModel = ContactModel(identity: creatorIdentity, nickname: "ECHOECHO")
    fileprivate lazy var groupModel = GroupCallsThreemaGroupModel(groupIdentity: groupIdentity, groupName: "TESTGROUP")
    
    @GlobalGroupCallActor
    func testBasicInit() async {
        let sfuBaseURL = ""
        let gck = Data(repeating: 0x01, count: 32)
        let dependencies = MockDependencies().create()
        
        let groupCallActor = try! GroupCallActor(
            localContactModel: localContactModel,
            groupModel: groupModel,
            sfuBaseURL: sfuBaseURL,
            gck: gck,
            dependencies: dependencies
        )
        
        let groupCallStartData = GroupCallStartData(
            protocolVersion: 0,
            gck: Data(repeating: 0x01, count: 32),
            sfuBaseURL: ""
        )
        
        let groupCallMessageCrypto = try! GroupCallBaseState(
            group: groupModel,
            startedAt: Date(),
            maxParticipants: Int.max,
            dependencies: dependencies,
            groupCallStartData: groupCallStartData
        )
        
        let groupCallCtx = MockGroupCallCtx(
            dependencies: dependencies,
            groupCallMessageCrypto: groupCallMessageCrypto
        )
        
        let connected = Connected(
            groupCallActor: groupCallActor,
            groupCallContext: groupCallCtx,
            participantIDs: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        )
        
        await groupCallActor.connectedConfirmed()
        
        let expectation = XCTestExpectation(description: "Connected cancelled")
        
        XCTAssertEqual(groupCallCtx.pendingParticipants.count, 0)
        XCTAssertEqual(groupCallCtx.participants.count, 0)
        
        let task = Task.detached {
            let newState = try await connected.next()
            
            XCTAssertTrue(newState is Ending)
            
            expectation.fulfill()
        }
        
        await Task.yield()
        
        // This isn't great since our tests will either succeed or fail by timing out
        // we never quickly discover that our tests fail. But otherwise we might not wait long enough for the state to
        // converge.
        while groupCallCtx.pendingParticipants.count != 10 {
            DDLogNotice("We have participants \(groupCallCtx.pendingParticipants.count)")
            await Task.yield()
        }
        
        DDLogNotice("We have participants \(groupCallCtx.pendingParticipants.count)")
        
        DDLogNotice("Cancel")
        
        task.cancel()
        groupCallCtx.cont.yield(PeerConnectionMessage(data: Data()))
        
        DDLogNotice("Cancelled")
        
        await Task.yield()
        
        // Ideally we'd want to avoid this sleep here and use `await fulfillment` instead of `wait`. But we still need
        // to run the tests on older versions of xcode
        // where that isn't available and the tests fail when not sleeping here. With `await fulfillment` the tests
        // don't fail.
        await Task.sleep(10 * 1000 * 1000)
        wait(for: [expectation], timeout: 30.0)
        
        XCTAssertEqual(groupCallCtx.pendingParticipants.count, 10)
        XCTAssertEqual(groupCallCtx.participants.count, 0)
    }
    
    // TODO: (IOS-3875) Timeout
    @GlobalGroupCallActor
    func testNewParticipantsJoin() async {
        let sfuBaseURL = ""
        let gck = Data(repeating: 0x01, count: 32)
        let dependencies = MockDependencies().create()
        
        let groupCallActor = try! GroupCallActor(
            localContactModel: localContactModel,
            groupModel: groupModel,
            sfuBaseURL: sfuBaseURL,
            gck: gck,
            dependencies: dependencies
        )
        
        let groupCallStartData = GroupCallStartData(
            protocolVersion: 0,
            gck: Data(repeating: 0x01, count: 32),
            sfuBaseURL: ""
        )
        
        let groupCallMessageCrypto = try! GroupCallBaseState(
            group: groupModel,
            startedAt: Date(),
            maxParticipants: Int.max,
            dependencies: dependencies,
            groupCallStartData: groupCallStartData
        )
        
        let groupCallCtx = MockGroupCallCtx(
            dependencies: dependencies,
            groupCallMessageCrypto: groupCallMessageCrypto
        )
        
        let connected = Connected(
            groupCallActor: groupCallActor,
            groupCallContext: groupCallCtx,
            participantIDs: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        )
        
        await groupCallActor.connectedConfirmed()
        
        let expectation = XCTestExpectation(description: "Connected cancelled")
        
        XCTAssertEqual(groupCallCtx.pendingParticipants.count, 0)
        XCTAssertEqual(groupCallCtx.participants.count, 0)
        
        let task = Task.detached {
            let newState = try await connected.next()
            
            XCTAssertTrue(newState is Ended)
            
            expectation.fulfill()
        }
        
        for i in 0..<50 {
            groupCallCtx.cont.yield(PeerConnectionMessage(data: joinMessage(for: UInt32(i))))
            await Task.yield()
        }
        
        // This isn't great since our tests will either succeed or fail by timing out
        // we never quickly discover that our tests fail. But otherwise we might not wait long enough for the state to
        // converge.
        var count = 0
        while groupCallCtx.pendingParticipants.count != 60 {
            print("Waiting for participants to show up \(count)")
            count += 1
            
            try! await Task.sleep(nanoseconds: 10_000_000)
            await Task.yield()
        }
        
        await Task.yield()
        
        DDLogNotice("Cancelling call")
        
        task.cancel()
        
        groupCallCtx.cont.yield(PeerConnectionMessage(data: Data()))
        
        await Task.yield()
        
        // Ideally we'd want to avoid this sleep here and use `await fulfillment` instead of `wait`. But we still need
        // to run the tests on older versions of xcode
        // where that isn't available and the tests fail when not sleeping here. With `await fulfillment` the tests
        // don't fail.
        await Task.sleep(10 * 1000 * 1000)
        wait(for: [expectation], timeout: 30.0)
        
        XCTAssertEqual(groupCallCtx.pendingParticipants.count, 60)
        XCTAssertEqual(groupCallCtx.participants.count, 0)
    }
    
    // TODO: (IOS-3875) Timeout
    #if compiler(>=5.8)
        func testNewParticipantsJoinInitiallyEmpty() async {
            let outerExpectation = XCTestExpectation(description: "Outer Expectation")
        
            Task.detached {
                let sfuBaseURL = ""
                let gck = Data(repeating: 0x01, count: 32)
                let dependencies = MockDependencies().create()
            
                let groupCallActor = try! GroupCallActor(
                    localContactModel: self.localContactModel,
                    groupModel: self.groupModel,
                    sfuBaseURL: sfuBaseURL,
                    gck: gck,
                    dependencies: dependencies
                )
            
                let groupCallStartData = GroupCallStartData(
                    protocolVersion: 0,
                    gck: Data(repeating: 0x01, count: 32),
                    sfuBaseURL: ""
                )
            
                let groupCallMessageCrypto = try! GroupCallBaseState(
                    group: self.groupModel,
                    startedAt: Date(),
                    maxParticipants: Int.max,
                    dependencies: dependencies,
                    groupCallStartData: groupCallStartData
                )
            
                let groupCallCtx = await MockGroupCallCtx(
                    dependencies: dependencies,
                    groupCallMessageCrypto: groupCallMessageCrypto
                )
            
                let connected = await Connected(
                    groupCallActor: groupCallActor,
                    groupCallContext: groupCallCtx,
                    participantIDs: []
                )
            
                let expectation = XCTestExpectation(description: "Connected cancelled")
            
                var numberOfPendingParticipants = await groupCallCtx.numberOfPendingParticipants()
                var numberOfParticipants = await groupCallCtx.numberOfParticipants()
                XCTAssertEqual(numberOfPendingParticipants, 0)
                XCTAssertEqual(numberOfParticipants, 0)
            
                let task = Task.detached {
                    let newState = try await connected.next()
                
                    XCTAssertTrue(newState is Ended)
                
                    expectation.fulfill()
                }
            
                for i in 0..<50 {
                    await groupCallCtx.cont.yield(PeerConnectionMessage(data: self.joinMessage(for: UInt32(i))))
                
                    await Task.yield()
                    await Task.yield()
                }
            
                if #available(iOS 16.0, *) {
                    try! await Task.sleep(for: .milliseconds(100))
                }
                else {
                    // Fallback on earlier versions
                }
            
                await Task.yield()
            
                task.cancel()
            
                await Task.yield()
            
                // Ideally we'd want to avoid this sleep here and use `await fulfillment` instead of `wait`. But we
                // still need to run the tests on older versions of Xcode
                // where that isn't available and the tests fail when not sleeping here. With `await fulfillment` the
                // tests don't fail.
                try! await Task.sleep(nanoseconds: 1 * 1000 * 1000)
            
                await self.fulfillment(of: [expectation], timeout: 10.0)
            
                numberOfPendingParticipants = await groupCallCtx.numberOfPendingParticipants()
                numberOfParticipants = await groupCallCtx.numberOfParticipants()
                XCTAssertEqual(numberOfPendingParticipants, 50)
                XCTAssertEqual(numberOfParticipants, 0)
            
                outerExpectation.fulfill()
            }
        
            await fulfillment(of: [outerExpectation], timeout: 10.0)
        }
    
    #endif
}

// MARK: - Helpers

extension ConnectedTests {
    private func joinMessage(for id: UInt32) -> Data {
        var participantJoined = Groupcall_SfuToParticipant.ParticipantJoined()
        participantJoined.participantID = id
        
        var envelope = Groupcall_SfuToParticipant.Envelope()
        envelope.participantJoined = participantJoined
        
        return try! envelope.ownSerializedData()
    }
}
