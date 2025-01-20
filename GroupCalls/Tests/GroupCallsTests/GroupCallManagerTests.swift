//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import CocoaLumberjack
import CocoaLumberjackSwift
import ThreemaEssentials
import ThreemaProtocols
import WebRTC
import XCTest
@testable import GroupCalls

final class GroupCallManagerTests: XCTestCase {
        
    fileprivate lazy var creatorIdentity = ThreemaIdentity("OCHEOCHE")
    fileprivate lazy var localIdentity = ThreemaIdentity("ECHOECHO")
    fileprivate lazy var localContactModel = ContactModel(identity: localIdentity, nickname: "ECHOECHO")
    fileprivate lazy var basicGroupIdentity = GroupIdentity(
        id: Data(repeating: 0x00, count: 8),
        creator: creatorIdentity
    )
    fileprivate lazy var basicGroupModel = GroupCallThreemaGroupModel(
        groupIdentity: basicGroupIdentity,
        groupName: "TESTGROUP"
    )
    fileprivate lazy var otherGroupIdentity = GroupIdentity(
        id: Data(repeating: 0x01, count: 8),
        creator: creatorIdentity
    )
    fileprivate lazy var otherGroupModel = GroupCallThreemaGroupModel(
        groupIdentity: otherGroupIdentity,
        groupName: "TESTGROUP"
    )
    fileprivate lazy var sfuBaseURL = URL(string: "sfu.threema.test")!
        
    // TODO: (IOS-3880) Test disabled: Check whether this still makes sense
    func testExample() async throws {
        let expectation = XCTestExpectation(description: "Handle succeeds")

        Task.detached {
            let dependencies = MockDependencies().create()

            let proposedGroupCall = try ProposedGroupCall(
                groupRepresentation: self.basicGroupModel,
                protocolVersion: 1,
                gck: Data(repeating: 0x03, count: 40),
                sfuBaseURL: self.sfuBaseURL,
                startMessageReceiveDate: Date(),
                dependencies: dependencies
            )

            let groupCallManager = GroupCallManager(
                dependencies: dependencies,
                localContactModel: self.localContactModel
            )

            await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: .db)

//                while await !(groupCallManager.hasRunningGroupCalls(in: proposedGroupCall)) {
//                    await Task.yield()
//                    try await Task.sleep(seconds: 1)
//                }

            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    // TODO: (IOS-3880) Test disabled: Check whether this still makes sense
    func test0() async throws {
        let expectation = XCTestExpectation(description: "Handle succeeds")

        let dependencies = MockDependencies().create()

        Task.detached {

            let groupCallManager = GroupCallManager(
                dependencies: dependencies,
                localContactModel: self.localContactModel
            )

            let proposedGroupCall1 = try ProposedGroupCall(
                groupRepresentation: self.basicGroupModel,
                protocolVersion: 1,
                gck: Data(repeating: 0x03, count: 40),
                sfuBaseURL: self.sfuBaseURL,
                startMessageReceiveDate: Date(),
                dependencies: dependencies
            )
            let proposedGroupCall2 = try ProposedGroupCall(
                groupRepresentation: self.basicGroupModel,
                protocolVersion: 1,
                gck: Data(repeating: 0x04, count: 40),
                sfuBaseURL: self.sfuBaseURL,
                startMessageReceiveDate: Date(),
                dependencies: dependencies
            )

            let proposedGroupCalls = [proposedGroupCall1, proposedGroupCall2]

            for proposedGroupCall in proposedGroupCalls {
                await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: .db)

//                    while await !(groupCallManager.hasRunningGroupCalls(in: proposedGroupCall)) {
//                        await Task.yield()
//                        try await Task.sleep(seconds: 1)
//                    }
            }

//                let allGroupCalls = await groupCallManager.groupCalls(in: groupModel)
//                for (i, allGroupCall) in allGroupCalls.enumerated() {
//                    let callID = allGroupCall.callID.bytes
//
//                    var response = ThreemaProtocols.Groupcall_SfuHttpResponse.Peek()
//                    response.startedAt = UInt64(i)
//                    response.maxParticipants = 100
//
//                    let urlResponse = HTTPURLResponse(
//                        url: URL(string: "http://threema.test")!,
//                        statusCode: 200,
//                        httpVersion: nil,
//                        headerFields: nil
//                    )!
//
//                    (dependencies.groupCallsHTTPClientAdapter as! MockHTTPClient)
//                        .responses[callID] = [(response, urlResponse)]
//                }

//                let viewModel = await groupCallManager.
//                let goldViewModel = await allGroupCalls.first!.viewModel
//
//                XCTAssertEqual(
//                    try Unmanaged.passUnretained(XCTUnwrap(viewModel)).toOpaque().hashValue,
//                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
//                )
//
//                var joinViewModel = await groupCallManager.joinCall(in: groupModel, intent: .join)
//
//                XCTAssertEqual(
//                    try Unmanaged.passUnretained(XCTUnwrap(joinViewModel)).toOpaque().hashValue,
//                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
//                )
//
//                joinViewModel = await groupCallManager.joinCall(in: groupModel, intent: .join)
//
//                XCTAssertEqual(
//                    try Unmanaged.passUnretained(XCTUnwrap(joinViewModel)).toOpaque().hashValue,
//                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
//                )

            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // TODO: (IOS-3880) Test disabled: Check whether this still makes sense
    func test1() async throws {
        let expectation = XCTestExpectation(description: "Handle succeeds")

        let dependencies = MockDependencies().create()
        let mockHTTPClient = (dependencies.groupCallsHTTPClientAdapter as! MockHTTPClient)
        let numberOfCalls = 20

        Task.detached {
            let localIdentity = "ECHOECHO"

            let groupCallManager = GroupCallManager(
                dependencies: dependencies,
                localContactModel: self.localContactModel
            )

            let proposedGroupCalls = (0..<numberOfCalls).map { i in
                try! ProposedGroupCall(
                    groupRepresentation: self.basicGroupModel,
                    protocolVersion: 1,
                    gck: Data(repeating: UInt8(i), count: 40),
                    sfuBaseURL: self.sfuBaseURL,
                    startMessageReceiveDate: Date(),
                    dependencies: dependencies
                )
            }

            XCTAssertEqual(proposedGroupCalls.count, numberOfCalls)

            for proposedGroupCall in proposedGroupCalls {
                await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: .db)
                    
//                    while await !(groupCallManager.hasRunningGroupCalls(in: proposedGroupCall)) {
//                        await Task.yield()
//                        try await Task.sleep(seconds: 1)
//                    }
            }

//                let allGroupCalls = await groupCallManager.groupCalls(in: groupModel)
//                for (i, allGroupCall) in allGroupCalls.enumerated() {
//                    let callID = allGroupCall.callID.bytes
//
//                    var response = ThreemaProtocols.Groupcall_SfuHttpResponse.Peek()
//                    response.startedAt = UInt64(i)
//                    response.maxParticipants = 100
//
//                    let firstURLResponse = HTTPURLResponse(
//                        url: URL(string: "http://threema.test")!,
//                        statusCode: 200,
//                        httpVersion: nil,
//                        headerFields: nil
//                    )!
//                    mockHTTPClient.responses[callID] = [(response, firstURLResponse)]
//
//                    let secondURLResponse = HTTPURLResponse(
//                        url: URL(string: "http://threema.test")!,
//                        statusCode: 404,
//                        httpVersion: nil,
//                        headerFields: nil
//                    )!
//                    mockHTTPClient.responses[callID]?.append((nil, secondURLResponse))
//                }

//                let viewModel = await groupCallManager.viewModel(for: groupModel)
//                var goldViewModel = await allGroupCalls.first!.viewModel
//
//                XCTAssertEqual(
//                    try Unmanaged.passUnretained(XCTUnwrap(viewModel)).toOpaque().hashValue,
//                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
//                )
//
//                var joinViewModel = await groupCallManager.joinCall(in: groupModel, intent: .join)
//
//                XCTAssertEqual(
//                    try Unmanaged.passUnretained(XCTUnwrap(joinViewModel)).toOpaque().hashValue,
//                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
//                )
//
//                joinViewModel = await groupCallManager.joinCall(in: groupModel, intent: .join)
//
//                XCTAssertEqual(
//                    try Unmanaged.passUnretained(XCTUnwrap(joinViewModel)).toOpaque().hashValue,
//                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
//                )
//
//                let firstCallCallID = allGroupCalls.first!.callID.bytes
//                mockHTTPClient.lock.withLock {
//                    _ = mockHTTPClient.responses[firstCallCallID]?.removeFirst()
//                }
//
//                print("Not running anymore \(firstCallCallID.hexEncodedString())")
//                print("New running \(allGroupCalls[1].callID.bytes.hexEncodedString())")
//                goldViewModel = await allGroupCalls[1].viewModel
//
//                joinViewModel = await groupCallManager.joinCall(in: groupModel, intent: .join)
//
//                XCTAssertEqual(mockHTTPClient.responses[firstCallCallID]!.count, 1)
//                XCTAssertEqual(
//                    try Unmanaged.passUnretained(XCTUnwrap(joinViewModel)).toOpaque().hashValue,
//                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
//                )

            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }
        
    func testPeekSteps() async throws {
        let dependencies = MockDependencies().create()
        let mockHTTPClient = (dependencies.groupCallsHTTPClientAdapter as! MockHTTPClient)
        let numberOfCalls = 20
            
        let groupCallManager = GroupCallManager(dependencies: dependencies, localContactModel: localContactModel)
            
        var groupCalls = Set<GroupCallActor>()
            
        for i in 0..<numberOfCalls {
            let newCall = try XCTUnwrap(GroupCallActor(
                localContactModel: localContactModel,
                groupModel: otherGroupModel,
                sfuBaseURL: URL(string: "https://\(i).test")!,
                gck: Data(repeating: UInt8(i), count: 32),
                dependencies: dependencies
            ))
                
            await newCall.setExactCallStartDate(UInt64(i))
                
            groupCalls.insert(newCall)
        }
            
        XCTAssertTrue(groupCalls.count == numberOfCalls)
            
        let goldChosenCall = groupCalls.randomElement()
        await goldChosenCall?.setExactCallStartDate(UInt64(numberOfCalls + 10))
            
        let chosenCall = try await groupCallManager.getCurrentlyChosenCall(from: groupCalls)
            
        await print(
            "Gold chosen call \(String(describing: goldChosenCall?.callID.bytes.hexEncodedString())) has start date \(String(describing: goldChosenCall?.exactCreationTimestamp))"
        )
        await print(
            "Actual chosen call \(String(describing: chosenCall?.callID.bytes.hexEncodedString())) has start date \(String(describing: chosenCall?.exactCreationTimestamp))"
        )
            
        let chosenStartDate = await chosenCall!.exactCreationTimestamp!
        for groupCall in groupCalls {
            let otherStartDate = await groupCall.exactCreationTimestamp!
            print("\(otherStartDate) < \(chosenStartDate)")
            let smaller = otherStartDate <= chosenStartDate
            XCTAssertTrue(smaller)
        }
            
        XCTAssert(goldChosenCall == chosenCall)
    }
        
    func testPeekStepsChosenCallChanges() async throws {
        let dependencies = MockDependencies().create()
        let mockHTTPClient = (dependencies.groupCallsHTTPClientAdapter as! MockHTTPClient)
        let numberOfCalls = 20
                        
        let groupCallManager = GroupCallManager(dependencies: dependencies, localContactModel: localContactModel)
            
        var groupCalls = Set<GroupCallActor>()
            
        for i in 0..<numberOfCalls {
            let newCall = try XCTUnwrap(GroupCallActor(
                localContactModel: localContactModel,
                groupModel: otherGroupModel,
                sfuBaseURL: URL(string: "https://\(i).test")!,
                gck: Data(repeating: UInt8(i), count: 32),
                dependencies: dependencies
            ))
                
            await newCall.setExactCallStartDate(UInt64(i))
                
            groupCalls.insert(newCall)
        }
            
        let goldChosenCall = groupCalls.randomElement()
        await goldChosenCall?.setExactCallStartDate(UInt64(numberOfCalls + 10))
            
        var chosenCall = try await groupCallManager.getCurrentlyChosenCall(from: groupCalls)
            
        XCTAssert(goldChosenCall == chosenCall)
            
        let newNumberOfCalls = numberOfCalls + 50
            
        for i in numberOfCalls..<newNumberOfCalls {
            let newCall = try XCTUnwrap(GroupCallActor(
                localContactModel: localContactModel,
                groupModel: otherGroupModel,
                sfuBaseURL: URL(string: "https://\(i).test")!,
                gck: Data(repeating: UInt8(i), count: 32),
                dependencies: dependencies
            ))
                
            await newCall.setExactCallStartDate(UInt64(i))
                
            groupCalls.insert(newCall)
        }
            
        let newGoldCall = try XCTUnwrap(GroupCallActor(
            localContactModel: localContactModel,
            groupModel: otherGroupModel,
            sfuBaseURL: URL(string: "sfu.threema.test")!,
            gck: Data(repeating: 0x01, count: 32),
            dependencies: dependencies
        ))
            
        await newGoldCall.setExactCallStartDate(UInt64(newNumberOfCalls + 1))
            
        groupCalls.insert(newGoldCall)
            
        chosenCall = try await groupCallManager.getCurrentlyChosenCall(from: groupCalls)
            
        XCTAssert(newGoldCall == chosenCall)
    }
}
