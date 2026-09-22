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
        
    // MARK: - Handling new call messages

    /// Handling several new call messages in the same group keeps all of them and signals the most recently started
    /// one as the currently running call.
    func testHandleNewCallMessagesForMultipleCallsInSameGroup() async throws {
        let setup = await makePeekTestSetup()
        let numberOfCalls = 5

        for i in 0..<numberOfCalls {
            let proposedGroupCall = try makeProposedGroupCall(
                for: setup,
                gck: Data(repeating: UInt8(i), count: 32)
            )

            // The start dates have to be at least one second apart to be distinguishable
            let callID = try XCTUnwrap(proposedGroupCall.hexCallID.hexadecimal)
            setup.httpClient.responses[callID] = [runningPeekResponse(startedAt: UInt64(i + 1) * 1000)]

            await setup.manager.handleNewCallMessage(
                for: proposedGroupCall,
                creatorOrigin: .db,
                calledFromExtension: false
            )
        }

        // All calls are still running, thus none of them was removed
        XCTAssertEqual(setup.databaseDelegate.removedCalls.count, 0)

        let trackedCallID = await setup.manager.getCallID(in: basicGroupModel)
        XCTAssertNotNil(trackedCallID)

        // The most recently started call is the chosen one
        let lastUpdate = try XCTUnwrap(setup.singletonDelegate.receivedBannerButtonUpdates.last)
        XCTAssertEqual(lastUpdate.groupIdentity, basicGroupIdentity)
        XCTAssertEqual(lastUpdate.startDate, Date(timeIntervalSince1970: TimeInterval(numberOfCalls)))
        XCTAssertFalse(lastUpdate.hideComponent)

        await setup.manager.cancelPeriodicRefresh()
    }

    // MARK: - Chosen call

    func testPeekSteps() async throws {
        let dependencies = MockDependencies().create()
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

    // MARK: - Create or Join

    /// **Protocol Step: Group Call Join Steps** Only one group call can be active at the same time: joining a call in
    /// another group while joining or joined is rejected, whereas joining the very same call again just shows it.
    func testCreateOrJoinCallRejectsSecondConcurrentJoin() async throws {
        let setup = await makePeekTestSetup()

        // Keep the created call in the `Joining` state for the duration of this test
        setup.httpClient.joinHangSeconds = 60

        try await setup.manager.createOrJoinCall(in: basicGroupModel, with: .createOrJoin)

        do {
            try await setup.manager.createOrJoinCall(in: otherGroupModel, with: .createOrJoin)
            XCTFail("Expected joining a call in another group to be rejected")
        }
        catch let error as GroupCallError {
            guard case .alreadyInCall = error else {
                XCTFail("Expected `alreadyInCall` but got \(error)")
                return
            }
        }

        // Joining the call we are already joining just shows it again and must not throw
        try await setup.manager.createOrJoinCall(in: basicGroupModel, with: .join)

        await setup.manager.cancelPeriodicRefresh()
    }

    // MARK: - New call messages from the notification extension (WP3)

    fileprivate func makeProposedGroupCall(
        for setup: PeekTestSetup,
        gck: Data = Data(repeating: 0x09, count: 32)
    ) throws -> ProposedGroupCall {
        try ProposedGroupCall(
            groupRepresentation: basicGroupModel,
            protocolVersion: 1,
            gck: gck,
            sfuBaseURL: sfuBaseURL,
            startMessageReceiveDate: Date(),
            dependencies: setup.dependencies
        )
    }

    /// The incoming call notification is shown from a detached task, thus we have to wait for it
    fileprivate func waitForIncomingCallNotification(in setup: PeekTestSetup, timeout: TimeInterval = 5) async {
        let deadline = Date(timeIntervalSinceNow: timeout)

        while setup.singletonDelegate.shownIncomingCallNotifications.isEmpty, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// In an extension context no call may be removed and no stored call may be deleted, since the app would never
    /// learn about the call in that case.
    func testHandleNewCallMessageFromExtensionNeverRemovesCalls() async throws {
        let setup = await makePeekTestSetup()
        let proposedGroupCall = try makeProposedGroupCall(for: setup)
        let callID = try XCTUnwrap(proposedGroupCall.hexCallID.hexadecimal)

        // The call is no longer running, which in the app would remove it
        setup.httpClient.responses[callID] = [(nil, httpResponse(status: 404))]

        await setup.manager.handleNewCallMessage(
            for: proposedGroupCall,
            creatorOrigin: .remote(creatorIdentity),
            calledFromExtension: true
        )

        XCTAssertEqual(setup.databaseDelegate.removedCalls.count, 0)
        XCTAssertFalse(setup.systemMessageAdapter.hasPostedGroupCallEnded)

        // The call has ended, thus there is nothing to notify about. We give a potential notification the chance to
        // arrive before we assert that there was none.
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(setup.singletonDelegate.shownIncomingCallNotifications.count, 0)
    }

    /// If we cannot determine whether the call is still running we notify the user: missing a running call is worse
    /// than a notification for a call that has just ended.
    func testHandleNewCallMessageNotifiesWhenPeekIsInconclusive() async throws {
        let setup = await makePeekTestSetup()
        let proposedGroupCall = try makeProposedGroupCall(for: setup)
        let callID = try XCTUnwrap(proposedGroupCall.hexCallID.hexadecimal)

        setup.httpClient.scriptedPeekErrors[callID] = [URLError(.notConnectedToInternet)]

        await setup.manager.handleNewCallMessage(
            for: proposedGroupCall,
            creatorOrigin: .remote(creatorIdentity),
            calledFromExtension: true
        )

        await waitForIncomingCallNotification(in: setup)

        XCTAssertEqual(setup.singletonDelegate.shownIncomingCallNotifications, [basicGroupIdentity])
        XCTAssertEqual(setup.databaseDelegate.removedCalls.count, 0)
        XCTAssertFalse(setup.systemMessageAdapter.hasPostedGroupCallEnded)
    }

    /// A running call notifies the user and stays tracked.
    func testHandleNewCallMessageNotifiesForRunningCall() async throws {
        let setup = await makePeekTestSetup()
        let proposedGroupCall = try makeProposedGroupCall(for: setup)
        let callID = try XCTUnwrap(proposedGroupCall.hexCallID.hexadecimal)

        setup.httpClient.responses[callID] = [runningPeekResponse()]

        await setup.manager.handleNewCallMessage(
            for: proposedGroupCall,
            creatorOrigin: .remote(creatorIdentity),
            calledFromExtension: true
        )

        await waitForIncomingCallNotification(in: setup)

        XCTAssertEqual(setup.singletonDelegate.shownIncomingCallNotifications, [basicGroupIdentity])

        let trackedCallID = await setup.manager.getCallID(in: basicGroupModel)
        XCTAssertEqual(trackedCallID, proposedGroupCall.hexCallID)
    }

    // MARK: - Group Call Refresh Steps: peek failure semantics (WP2)

    // These tests encode the desired behavior of the protocol's "Group Call Refresh Steps":
    // only an authoritative "not running" (HTTP 404) may remove a call from the running list.
    // Timeouts, network errors, 5xx and decode failures must keep the call and use the
    // failed-counter path (remove only if failedCounter >= 3 AND received more than 10h ago).

    fileprivate struct PeekTestSetup {
        let manager: GroupCallManager
        let httpClient: MockHTTPClient
        let systemMessageAdapter: MockGroupCallSystemMessageAdapter
        let databaseDelegate: MockDatabaseDelegate
        let singletonDelegate: MockGroupCallManagerSingletonDelegate
        let dependencies: Dependencies
    }

    fileprivate func makePeekTestSetup() async -> PeekTestSetup {
        let dependencies = MockDependencies().create()
        let httpClient = dependencies.groupCallsHTTPClientAdapter as! MockHTTPClient
        httpClient.autoDropResponses = false

        let systemMessageAdapter = dependencies.groupCallSystemMessageAdapter as! MockGroupCallSystemMessageAdapter

        let manager = GroupCallManager(dependencies: dependencies, localContactModel: localContactModel)
        let databaseDelegate = MockDatabaseDelegate()
        await manager.set(databaseDelegate: databaseDelegate)
        let singletonDelegate = MockGroupCallManagerSingletonDelegate()
        await manager.set(singletonDelegate: singletonDelegate)

        return PeekTestSetup(
            manager: manager,
            httpClient: httpClient,
            systemMessageAdapter: systemMessageAdapter,
            databaseDelegate: databaseDelegate,
            singletonDelegate: singletonDelegate,
            dependencies: dependencies
        )
    }

    fileprivate func addTrackedCall(
        to setup: PeekTestSetup,
        gck: Data = Data(repeating: 0x07, count: 32),
        protocolVersion: UInt32 = 1,
        receivedAgo: TimeInterval = 0,
        peekTimeout: TimeInterval = ProtocolDefines.peekTimeout
    ) async throws -> GroupCallActor {
        let call = try GroupCallActor(
            localContactModel: localContactModel,
            groupModel: basicGroupModel,
            sfuBaseURL: sfuBaseURL,
            gck: gck,
            protocolVersion: protocolVersion,
            startMessageReceiveDate: Date(timeIntervalSinceNow: -receivedAgo),
            peekTimeout: peekTimeout,
            dependencies: setup.dependencies
        )

        await setup.manager.addToRunningGroupCalls(groupCall: call)

        return call
    }

    fileprivate func httpResponse(status: Int) -> URLResponse {
        HTTPURLResponse(
            url: URL(string: "http://threema.test")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    fileprivate func runningPeekResponse(startedAt: UInt64 = 1) -> (MockHTTPClient.PeekResponse?, URLResponse) {
        var peekResponse = MockHTTPClient.PeekResponse()
        peekResponse.startedAt = startedAt
        peekResponse.maxParticipants = 100

        return (peekResponse, httpResponse(status: 200))
    }

    /// **Protocol Step: Periodic Refresh** 5.: When the chosen call ends, the call with the next highest `started_at`
    /// becomes the chosen call.
    func testChosenCallSwitchesWhenNewerCallEnds() async throws {
        let setup = await makePeekTestSetup()

        let olderCall = try makeProposedGroupCall(for: setup, gck: Data(repeating: 0x01, count: 32))
        let newerCall = try makeProposedGroupCall(for: setup, gck: Data(repeating: 0x02, count: 32))

        let olderCallID = try XCTUnwrap(olderCall.hexCallID.hexadecimal)
        let newerCallID = try XCTUnwrap(newerCall.hexCallID.hexadecimal)

        setup.httpClient.responses[olderCallID] = [runningPeekResponse(startedAt: 1000)]
        setup.httpClient.responses[newerCallID] = [runningPeekResponse(startedAt: 2000)]

        for proposedGroupCall in [olderCall, newerCall] {
            await setup.manager.handleNewCallMessage(
                for: proposedGroupCall,
                creatorOrigin: .db,
                calledFromExtension: false
            )
        }

        // The newer call is the chosen one
        var lastUpdate = try XCTUnwrap(setup.singletonDelegate.receivedBannerButtonUpdates.last)
        XCTAssertEqual(lastUpdate.startDate, Date(timeIntervalSince1970: 2))

        // The newer call ends
        setup.httpClient.responses[newerCallID] = [(nil, httpResponse(status: 404))]

        await setup.manager.refreshGroupCalls(in: basicGroupIdentity)

        // Only the ended call was removed and the older call is the chosen one now
        XCTAssertEqual(setup.databaseDelegate.removedCalls.map(\.hexCallID), [newerCall.hexCallID])

        lastUpdate = try XCTUnwrap(setup.singletonDelegate.receivedBannerButtonUpdates.last)
        XCTAssertEqual(lastUpdate.startDate, Date(timeIntervalSince1970: 1))
        XCTAssertFalse(lastUpdate.hideComponent)

        await setup.manager.cancelPeriodicRefresh()
    }

    /// **Protocol Step: Periodic Refresh** 4.3: a 404 is the only peek result that removes the call.
    func testPeek404RemovesCallAndDeletesFromDB() async throws {
        let setup = await makePeekTestSetup()
        let call = try await addTrackedCall(to: setup)

        setup.httpClient.responses[call.callID.bytes] = [(nil, httpResponse(status: 404))]

        await setup.manager.refreshGroupCalls(in: basicGroupIdentity)

        let trackedCallID = await setup.manager.getCallID(in: basicGroupModel)
        XCTAssertNil(trackedCallID)
        XCTAssertEqual(setup.databaseDelegate.removedCalls.count, 1)
        XCTAssertTrue(setup.systemMessageAdapter.hasPostedGroupCallEnded)
    }

    /// **Protocol Step: Periodic Refresh** 4.6: a 5xx means "failed", the call is kept and the
    /// failed counter incremented. No system message, no DB deletion.
    func testPeek500KeepsCallAndIncrementsFailedCounter() async throws {
        let setup = await makePeekTestSetup()
        let call = try await addTrackedCall(to: setup)

        setup.httpClient.responses[call.callID.bytes] = [(nil, httpResponse(status: 500))]

        await setup.manager.refreshGroupCalls(in: basicGroupIdentity)

        let trackedCallID = await setup.manager.getCallID(in: basicGroupModel)
        XCTAssertNotNil(trackedCallID)

        let failedCounter = await call.failedCounter
        XCTAssertEqual(failedCounter, 1)
        XCTAssertEqual(setup.databaseDelegate.removedCalls.count, 0)
        XCTAssertEqual(setup.systemMessageAdapter.postedSystemMessages.count, 0)
    }

    /// **Protocol Step: Periodic Refresh** 4.6: an unreachable server means "failed", same as a 5xx.
    func testPeekNetworkErrorKeepsCallAndIncrementsFailedCounter() async throws {
        let setup = await makePeekTestSetup()
        let call = try await addTrackedCall(to: setup)

        setup.httpClient.scriptedPeekErrors[call.callID.bytes] = [URLError(.notConnectedToInternet)]

        await setup.manager.refreshGroupCalls(in: basicGroupIdentity)

        let trackedCallID = await setup.manager.getCallID(in: basicGroupModel)
        XCTAssertNotNil(trackedCallID)

        let failedCounter = await call.failedCounter
        XCTAssertEqual(failedCounter, 1)
        XCTAssertEqual(setup.databaseDelegate.removedCalls.count, 0)
        XCTAssertEqual(setup.systemMessageAdapter.postedSystemMessages.count, 0)
    }

    /// **Protocol Step: Periodic Refresh** 4.4: a peek timeout means "unknown", the call is kept
    /// (skipped for this round) and the failed counter is not touched.
    func testPeekTimeoutKeepsCall() async throws {
        let setup = await makePeekTestSetup()
        let call = try await addTrackedCall(to: setup, peekTimeout: 0.5)

        setup.httpClient.peekHangSeconds[call.callID.bytes] = 2

        await setup.manager.refreshGroupCalls(in: basicGroupIdentity)

        let trackedCallID = await setup.manager.getCallID(in: basicGroupModel)
        XCTAssertNotNil(trackedCallID)

        let failedCounter = await call.failedCounter
        XCTAssertEqual(failedCounter, 0)
        XCTAssertEqual(setup.databaseDelegate.removedCalls.count, 0)
        XCTAssertEqual(setup.systemMessageAdapter.postedSystemMessages.count, 0)
    }

    /// **Protocol Step: Periodic Refresh** 4.6.2: removal requires failedCounter >= 3 AND received
    /// more than 10h ago. A call received more than 10h ago must survive its first failed peek.
    func testOldCallSurvivesFirstFailedPeek() async throws {
        let setup = await makePeekTestSetup()
        let call = try await addTrackedCall(to: setup, receivedAgo: 11 * 60 * 60)

        setup.httpClient.responses[call.callID.bytes] = [(nil, httpResponse(status: 500))]

        await setup.manager.refreshGroupCalls(in: basicGroupIdentity)

        let trackedCallID = await setup.manager.getCallID(in: basicGroupModel)
        XCTAssertNotNil(trackedCallID)

        let failedCounter = await call.failedCounter
        XCTAssertEqual(failedCounter, 1)
        XCTAssertEqual(setup.databaseDelegate.removedCalls.count, 0)
    }

    /// **Protocol Step: Periodic Refresh** 4.6.2: a young call is kept no matter how high the
    /// failed counter is; an old call with failedCounter >= 3 is removed.
    func testCallRemovedOnlyWhenCounterAndAgeExceeded() async throws {
        // Young call with failedCounter >= 3 is kept
        let youngSetup = await makePeekTestSetup()
        let youngCall = try await addTrackedCall(to: youngSetup)

        await youngCall.incrementFailedCounter()
        await youngCall.incrementFailedCounter()
        await youngCall.incrementFailedCounter()

        youngSetup.httpClient.responses[youngCall.callID.bytes] = [(nil, httpResponse(status: 500))]

        await youngSetup.manager.refreshGroupCalls(in: basicGroupIdentity)

        let youngTrackedCallID = await youngSetup.manager.getCallID(in: basicGroupModel)
        XCTAssertNotNil(youngTrackedCallID)
        XCTAssertEqual(youngSetup.databaseDelegate.removedCalls.count, 0)

        // Old call with failedCounter >= 3 is removed
        let oldSetup = await makePeekTestSetup()
        let oldCall = try await addTrackedCall(to: oldSetup, receivedAgo: 11 * 60 * 60)

        await oldCall.incrementFailedCounter()
        await oldCall.incrementFailedCounter()
        await oldCall.incrementFailedCounter()

        oldSetup.httpClient.responses[oldCall.callID.bytes] = [(nil, httpResponse(status: 500))]

        await oldSetup.manager.refreshGroupCalls(in: basicGroupIdentity)

        let oldTrackedCallID = await oldSetup.manager.getCallID(in: basicGroupModel)
        XCTAssertNil(oldTrackedCallID)
        XCTAssertEqual(oldSetup.databaseDelegate.removedCalls.count, 1)
    }

    /// **Protocol Step: Periodic Refresh** 4.2: a successful peek resets the failed counter.
    func testSuccessfulPeekResetsFailedCounter() async throws {
        let setup = await makePeekTestSetup()
        let call = try await addTrackedCall(to: setup)

        await call.incrementFailedCounter()
        await call.incrementFailedCounter()

        setup.httpClient.responses[call.callID.bytes] = [runningPeekResponse()]

        await setup.manager.refreshGroupCalls(in: basicGroupIdentity)

        let trackedCallID = await setup.manager.getCallID(in: basicGroupModel)
        XCTAssertNotNil(trackedCallID)

        let failedCounter = await call.failedCounter
        XCTAssertEqual(failedCounter, 0)
    }

    /// **Protocol Step: Periodic Refresh** 4.5: an unsupported protocol version logs a warning and keeps the call
    /// tracked including its DB entity, but the call was removed from `calls` and thus must never be chosen.
    func testUnsupportedProtocolVersionKeepsCallButNeverChoosesIt() async throws {
        let setup = await makePeekTestSetup()

        let supportedCall = try await addTrackedCall(to: setup, gck: Data(repeating: 0x07, count: 32))
        let unsupportedCall = try await addTrackedCall(
            to: setup,
            gck: Data(repeating: 0x08, count: 32),
            protocolVersion: 99
        )

        // The unsupported call started later, thus it would be the chosen call if its version was supported
        setup.httpClient.responses[supportedCall.callID.bytes] = [runningPeekResponse(startedAt: 1000)]
        setup.httpClient.responses[unsupportedCall.callID.bytes] = [runningPeekResponse(startedAt: 2000)]

        await setup.manager.refreshGroupCalls(in: basicGroupIdentity)

        // Both calls are kept …
        let trackedCallID = await setup.manager.getCallID(in: basicGroupModel)
        XCTAssertNotNil(trackedCallID)
        XCTAssertEqual(setup.databaseDelegate.removedCalls.count, 0)
        XCTAssertEqual(setup.systemMessageAdapter.postedSystemMessages.count, 0)

        let failedCounter = await unsupportedCall.failedCounter
        XCTAssertEqual(failedCounter, 0)

        // … but the call with the supported protocol version is the chosen one
        let lastUpdate = try XCTUnwrap(setup.singletonDelegate.receivedBannerButtonUpdates.last)
        XCTAssertEqual(lastUpdate.startDate, Date(timeIntervalSince1970: 1))
    }
}
