//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import ThreemaProtocols
import WebRTC
import XCTest
@testable import GroupCalls

#if compiler(>=5.8)
    final class GroupCallManagerTests: XCTestCase {
        // TODO: Test disabled: Check whether this still makes sense
        func testExample() async throws {
            let expectation = XCTestExpectation(description: "Handle succeeds")

            Task.detached {
                let dependencies = MockDependencies().create()
                let localIdentity = "ECHOECHO"

                let members: Set<ThreemaID> = [try XCTUnwrap(ThreemaID(id: "ECHOECHO"))]
                let groupModel = try GroupCallsThreemaGroupModel(
                    creator: XCTUnwrap(ThreemaID(id: "ECHOECHO")),
                    groupID: Data(),
                    groupName: "ECHOECHO",
                    members: members
                )

                let proposedGroupCall = ProposedGroupCall(
                    groupRepresentation: groupModel,
                    protocolVersion: 1,
                    gck: Data(repeating: 0x03, count: 40),
                    sfuBaseURL: "sfu.threema.test",
                    startMessageReceiveDate: Date(),
                    dependencies: dependencies
                )

                let groupCallManager = GroupCallManager(dependencies: dependencies, localIdentity: localIdentity)

                await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: .db)

                while await !(groupCallManager.hasRunningGroupCalls(in: proposedGroupCall)) {
                    await Task.yield()
                    try await Task.sleep(seconds: 1)
                }

                expectation.fulfill()
            }

            await fulfillment(of: [expectation], timeout: 5.0)
        }

        // TODO: Test disabled: Check whether this still makes sense
        func test0() async throws {
            let expectation = XCTestExpectation(description: "Handle succeeds")

            let dependencies = MockDependencies().create()

            Task.detached {
                let localIdentity = "ECHOECHO"

                let groupCallManager = GroupCallManager(dependencies: dependencies, localIdentity: localIdentity)

                let members: Set<ThreemaID> = [try XCTUnwrap(ThreemaID(id: "ECHOECHO"))]
                let groupModel = try GroupCallsThreemaGroupModel(
                    creator: XCTUnwrap(ThreemaID(id: "ECHOECHO")),
                    groupID: Data(),
                    groupName: "ECHOECHO",
                    members: members
                )

                let proposedGroupCall1 = ProposedGroupCall(
                    groupRepresentation: groupModel,
                    protocolVersion: 1,
                    gck: Data(repeating: 0x03, count: 40),
                    sfuBaseURL: "sfu.threema.test",
                    startMessageReceiveDate: Date(),
                    dependencies: dependencies
                )
                let proposedGroupCall2 = ProposedGroupCall(
                    groupRepresentation: groupModel,
                    protocolVersion: 1,
                    gck: Data(repeating: 0x04, count: 40),
                    sfuBaseURL: "sfu.threema.test",
                    startMessageReceiveDate: Date(),
                    dependencies: dependencies
                )

                let proposedGroupCalls = [proposedGroupCall1, proposedGroupCall2]

                for proposedGroupCall in proposedGroupCalls {
                    await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: .db)

                    while await !(groupCallManager.hasRunningGroupCalls(in: proposedGroupCall)) {
                        await Task.yield()
                        try await Task.sleep(seconds: 1)
                    }
                }

                let allGroupCalls = await groupCallManager.groupCalls(in: groupModel)
                for (i, allGroupCall) in allGroupCalls.enumerated() {
                    let callID = allGroupCall.callID.bytes

                    var response = ThreemaProtocols.Groupcall_SfuHttpResponse.Peek()
                    response.startedAt = UInt64(i)
                    response.maxParticipants = 100

                    let urlResponse = HTTPURLResponse(
                        url: URL(string: "http://threema.test")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!

                    (dependencies.groupCallsHTTPClientAdapter as! MockHTTPClient)
                        .responses[callID] = [(response, urlResponse)]
                }

                let viewModel = await groupCallManager.viewModel(for: groupModel)
                let goldViewModel = await allGroupCalls.first!.viewModel

                XCTAssertEqual(
                    try Unmanaged.passUnretained(XCTUnwrap(viewModel)).toOpaque().hashValue,
                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
                )

                var joinViewModel = await groupCallManager.joinCall(in: groupModel, intent: .join)

                XCTAssertTrue(joinViewModel.0)
                XCTAssertEqual(
                    try Unmanaged.passUnretained(XCTUnwrap(joinViewModel.1)).toOpaque().hashValue,
                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
                )

                joinViewModel = await groupCallManager.joinCall(in: groupModel, intent: .join)

                XCTAssertTrue(joinViewModel.0)
                XCTAssertEqual(
                    try Unmanaged.passUnretained(XCTUnwrap(joinViewModel.1)).toOpaque().hashValue,
                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
                )

                expectation.fulfill()
            }

            await fulfillment(of: [expectation], timeout: 5.0)
        }
    
        // TODO: Test disabled: Check whether this still makes sense
        func test1() async throws {
            let expectation = XCTestExpectation(description: "Handle succeeds")

            let dependencies = MockDependencies().create()
            let mockHTTPClient = (dependencies.groupCallsHTTPClientAdapter as! MockHTTPClient)
            let numberOfCalls = 20

            Task.detached {
                let localIdentity = "ECHOECHO"

                let groupCallManager = GroupCallManager(dependencies: dependencies, localIdentity: localIdentity)

                let members: Set<ThreemaID> = [try XCTUnwrap(ThreemaID(id: "ECHOECHO"))]
                let groupModel = try GroupCallsThreemaGroupModel(
                    creator: XCTUnwrap(ThreemaID(id: "ECHOECHO")),
                    groupID: Data(),
                    groupName: "ECHOECHO",
                    members: members
                )

                let proposedGroupCalls = (0..<numberOfCalls).map { i in
                    ProposedGroupCall(
                        groupRepresentation: groupModel,
                        protocolVersion: 1,
                        gck: Data(repeating: UInt8(i), count: 40),
                        sfuBaseURL: "sfu.threema.test",
                        startMessageReceiveDate: Date(),
                        dependencies: dependencies
                    )
                }

                XCTAssertEqual(proposedGroupCalls.count, numberOfCalls)

                for proposedGroupCall in proposedGroupCalls {
                    await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: .db)
                    
                    while await !(groupCallManager.hasRunningGroupCalls(in: proposedGroupCall)) {
                        await Task.yield()
                        try await Task.sleep(seconds: 1)
                    }
                }

                let allGroupCalls = await groupCallManager.groupCalls(in: groupModel)
                for (i, allGroupCall) in allGroupCalls.enumerated() {
                    let callID = allGroupCall.callID.bytes

                    var response = ThreemaProtocols.Groupcall_SfuHttpResponse.Peek()
                    response.startedAt = UInt64(i)
                    response.maxParticipants = 100

                    let firstURLResponse = HTTPURLResponse(
                        url: URL(string: "http://threema.test")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    mockHTTPClient.responses[callID] = [(response, firstURLResponse)]

                    let secondURLResponse = HTTPURLResponse(
                        url: URL(string: "http://threema.test")!,
                        statusCode: 404,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    mockHTTPClient.responses[callID]?.append((nil, secondURLResponse))
                }

                let viewModel = await groupCallManager.viewModel(for: groupModel)
                var goldViewModel = await allGroupCalls.first!.viewModel

                XCTAssertEqual(
                    try Unmanaged.passUnretained(XCTUnwrap(viewModel)).toOpaque().hashValue,
                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
                )

                var joinViewModel = await groupCallManager.joinCall(in: groupModel, intent: .join)

                XCTAssertTrue(joinViewModel.0)
                XCTAssertEqual(
                    try Unmanaged.passUnretained(XCTUnwrap(joinViewModel.1)).toOpaque().hashValue,
                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
                )

                joinViewModel = await groupCallManager.joinCall(in: groupModel, intent: .join)

                XCTAssertTrue(joinViewModel.0)
                XCTAssertEqual(
                    try Unmanaged.passUnretained(XCTUnwrap(joinViewModel.1)).toOpaque().hashValue,
                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
                )

                let firstCallCallID = allGroupCalls.first!.callID.bytes
                mockHTTPClient.lock.withLock {
                    _ = mockHTTPClient.responses[firstCallCallID]?.removeFirst()
                }

                print("Not running anymore \(firstCallCallID.hexEncodedString())")
                print("New running \(allGroupCalls[1].callID.bytes.hexEncodedString())")

                goldViewModel = await allGroupCalls[1].viewModel

                joinViewModel = await groupCallManager.joinCall(in: groupModel, intent: .join)

                XCTAssertEqual(mockHTTPClient.responses[firstCallCallID]!.count, 1)
                XCTAssertTrue(joinViewModel.0)
                XCTAssertEqual(
                    try Unmanaged.passUnretained(XCTUnwrap(joinViewModel.1)).toOpaque().hashValue,
                    Unmanaged.passUnretained(goldViewModel).toOpaque().hashValue
                )

                expectation.fulfill()
            }

            await fulfillment(of: [expectation], timeout: 5.0)
        }
        
        func testPeekSteps() async throws {
            let dependencies = MockDependencies().create()
            let mockHTTPClient = (dependencies.groupCallsHTTPClientAdapter as! MockHTTPClient)
            let numberOfCalls = 20
            
            let localIdentity = "ECHOECHO"
            
            let groupCallManager = GroupCallManager(dependencies: dependencies, localIdentity: localIdentity)
            
            let members: Set<ThreemaID> = [try XCTUnwrap(ThreemaID(id: "ECHOECHO"))]
            let groupModel = try GroupCallsThreemaGroupModel(
                creator: XCTUnwrap(ThreemaID(id: "ECHOECHO")),
                groupID: Data(repeating: 0x01, count: 32),
                groupName: "ECHOECHO",
                members: members
            )
            
            var groupCalls = Set<GroupCallActor>()
            
            for i in 0..<numberOfCalls {
                let newCall = try XCTUnwrap(GroupCallActor(
                    localIdentity: XCTUnwrap(ThreemaID(id: "ECHOECHO")),
                    groupModel: groupModel,
                    sfuBaseURL: "https://\(i).test",
                    gck: Data(repeating: UInt8(i), count: 32),
                    dependencies: dependencies
                ))
                
                await newCall.setExactCallStartDate(UInt64(i))
                
                groupCalls.insert(newCall)
            }
            
            XCTAssertTrue(groupCalls.count == numberOfCalls)
            
            let goldChosenCall = groupCalls.randomElement()
            await goldChosenCall?.setExactCallStartDate(UInt64(numberOfCalls + 10))
            
            let chosenCall = try await groupCallManager.getCurrentlyChosenCall(in: groupModel, from: groupCalls)
            
            await print(
                "Gold chosen call \(String(describing: goldChosenCall?.callID.bytes.hexEncodedString())) has start date \(String(describing: goldChosenCall?.exactCallStartDate))"
            )
            await print(
                "Actual chosen call \(String(describing: chosenCall?.callID.bytes.hexEncodedString())) has start date \(String(describing: chosenCall?.exactCallStartDate))"
            )
            
            let chosenStartDate = await chosenCall!.exactCallStartDate!
            for groupCall in groupCalls {
                let otherStartDate = await groupCall.exactCallStartDate!
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
            
            let localIdentity = "ECHOECHO"
            
            let groupCallManager = GroupCallManager(dependencies: dependencies, localIdentity: localIdentity)
            
            let members: Set<ThreemaID> = [try XCTUnwrap(ThreemaID(id: "ECHOECHO"))]
            let groupModel = try GroupCallsThreemaGroupModel(
                creator: XCTUnwrap(ThreemaID(id: "ECHOECHO")),
                groupID: Data(repeating: 0x01, count: 32),
                groupName: "ECHOECHO",
                members: members
            )
            
            var groupCalls = Set<GroupCallActor>()
            
            for i in 0..<numberOfCalls {
                let newCall = try XCTUnwrap(GroupCallActor(
                    localIdentity: XCTUnwrap(ThreemaID(id: "ECHOECHO")),
                    groupModel: groupModel,
                    sfuBaseURL: "https://\(i).test",
                    gck: Data(repeating: UInt8(i), count: 32),
                    dependencies: dependencies
                ))
                
                await newCall.setExactCallStartDate(UInt64(i))
                
                groupCalls.insert(newCall)
            }
            
            let goldChosenCall = groupCalls.randomElement()
            await goldChosenCall?.setExactCallStartDate(UInt64(numberOfCalls + 10))
            
            var chosenCall = try await groupCallManager.getCurrentlyChosenCall(in: groupModel, from: groupCalls)
            
            XCTAssert(goldChosenCall == chosenCall)
            
            let newNumberOfCalls = numberOfCalls + 50
            
            for i in numberOfCalls..<newNumberOfCalls {
                let newCall = try XCTUnwrap(GroupCallActor(
                    localIdentity: XCTUnwrap(ThreemaID(id: "ECHOECHO")),
                    groupModel: groupModel,
                    sfuBaseURL: "https://\(i).test",
                    gck: Data(repeating: UInt8(i), count: 32),
                    dependencies: dependencies
                ))
                
                await newCall.setExactCallStartDate(UInt64(i))
                
                groupCalls.insert(newCall)
            }
            
            let newGoldCall = try XCTUnwrap(GroupCallActor(
                localIdentity: XCTUnwrap(ThreemaID(id: "ECHOECHO")),
                groupModel: groupModel,
                sfuBaseURL: "",
                gck: Data(repeating: 0x01, count: 32),
                dependencies: dependencies
            ))
            
            await newGoldCall.setExactCallStartDate(UInt64(newNumberOfCalls + 1))
            
            groupCalls.insert(newGoldCall)
            
            chosenCall = try await groupCallManager.getCurrentlyChosenCall(in: groupModel, from: groupCalls)
            
            XCTAssert(newGoldCall == chosenCall)
        }
    }

#endif
