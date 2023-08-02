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

import CocoaLumberjackSwift
import Combine
import CryptoKit
import Foundation
import ThreemaProtocols
import WebRTC

public protocol GroupCallManagerDatabaseDelegateProtocol: Sendable {
    func removeFromStoredCalls(_ groupCall: ProposedGroupCall)
}

/// Handles all group calls that we know of.
/// Periodically checks whether calls are still running.
///
/// In the app this is used through the `GlobalGroupCallsManagerSingleton` class.
public final actor GroupCallManager {
    // MARK: - Nested Types
    
    public enum GroupCallManagerError: Error {
        case CannotJoinAlreadyInACall
    }
    
    fileprivate enum PeriodicRefreshResult {
        case keep
        case remove
        case retry
    }
    
    // MARK: - Public Properties
    
    public let globalGroupCallObserver = AsyncStreamContinuationToSharedPublisher<GroupCallsThreemaGroupModel>()
    
    // MARK: - Private Properties
    
    private var currentlyRunningGroupCalls = Set<GroupCallActor>()
    
    private let dependencies: Dependencies
    
    private let localIdentity: ThreemaID
    
    var periodicCallCheckTask: Task<Void, Never>?
    var currentCallCheckTask: Task<Void, Error>?
    
    // MARK: - Delegation
    
    var databaseDelegate: GroupCallManagerDatabaseDelegateProtocol?
    public func set(databaseDelegate: GroupCallManagerDatabaseDelegateProtocol) {
        self.databaseDelegate = databaseDelegate
    }
    
    private weak var uiDelegate: GroupCallManagerUIDelegate?
    public func set(uiDelegate: GroupCallManagerUIDelegate) {
        self.uiDelegate = uiDelegate
    }
    
    // MARK: - Lifecycle
    
    public init(
        dependencies: Dependencies,
        localIdentity: String,
        databaseDelegate: GroupCallManagerDatabaseDelegateProtocol? = nil,
        uiDelegate: GroupCallManagerUIDelegate? = nil
    ) {
        self.dependencies = dependencies
        self.databaseDelegate = databaseDelegate
        
        // TODO: Do not force unwrap here
        self.localIdentity = try! ThreemaID(id: localIdentity, nickname: nil)
    }
    
    func startPeriodicCheckIfNeeded() {
        guard periodicCallCheckTask == nil else {
            return
        }
        periodicCallCheckTask = Task { [weak self] in
            while let self {
                try? await self.checkCallsStillRunning()
                try? await Task.sleep(seconds: 10)
            }
        }
    }
    
    // MARK: - Update Functions
    
    /// Handles a new call message, either freshly received or loaded from DB
    /// - Parameters:
    ///   - proposedGroupCall: Proposed
    ///   - creatorOrigin: Where the proposed call stems from
    public func handleNewCallMessage(
        for proposedGroupCall: ProposedGroupCall,
        creatorOrigin: GroupCallCreatorOrigin
    ) async {
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] [Message Processor] \(#function)")
        DDLogNotice("[GroupCall] [Message Processor] \(#function) with callID \(proposedGroupCall.hexCallID)")
        
        startPeriodicCheckIfNeeded()
        
        let groupModel = GroupCallsThreemaGroupModel(
            creator: proposedGroupCall.groupRepresentation.creator,
            groupID: proposedGroupCall.groupRepresentation.groupID,
            groupName: proposedGroupCall.groupRepresentation.groupName,
            members: proposedGroupCall.groupRepresentation.members
        )
        
        do {
            let newGroupCall = try GroupCallActor(
                localIdentity: localIdentity,
                groupModel: groupModel,
                sfuBaseURL: proposedGroupCall.sfuBaseURL,
                gck: proposedGroupCall.gck,
                dependencies: dependencies
            )
            
            // TODO: (IOS-3857) Logging
            DDLogNotice("[GroupCall] Add call \(newGroupCall.logIdentifier)")
            currentlyRunningGroupCalls.insert(newGroupCall)
            
            try await checkCallsStillRunning()
            
            // Post system message
            do {
                switch creatorOrigin {
                case let .remote(threemaID):
                    try await dependencies.groupCallSystemMessageAdapter.post(
                        .groupCallStartedBy(threemaID),
                        in: groupModel
                    )
                case .local:
                    try await dependencies.groupCallSystemMessageAdapter.post(
                        .groupCallStarted,
                        in: groupModel
                    )
                case .db:
                    break
                }
            }
            catch {
                if let error = error as? GroupCallSystemMessageAdapterError {
                    DDLogError("[GroupCall] An error occurred when attempting to post a system message \(error)")
                }
            }
            // TODO: (IOS-3857) Logging
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] After adding \(newGroupCall.logIdentifier). We have currently \(currentlyRunningGroupCalls.count) calls running"
            )
        }
        catch {
            DDLogError("[GroupCall] An error occurred when adding a new group call \(error)")
        }
    }
    
    public func hasRunningGroupCalls(in proposedGroupCall: ProposedGroupCall) async -> Bool {
        !(groupCalls(in: proposedGroupCall.groupRepresentation).filter { groupCallActor in
            guard groupCallActor.protocolVersion == proposedGroupCall.protocolVersion else {
                return false
            }
            
            guard let proposedCallID = try? GroupCallID(
                group: proposedGroupCall.groupRepresentation,
                callStartData: GroupCallStartData(
                    protocolVersion: proposedGroupCall.protocolVersion,
                    gck: proposedGroupCall.gck,
                    sfuBaseURL: proposedGroupCall.sfuBaseURL
                ),
                dependencies: dependencies
            ) else {
                DDLogError("[GroupCall] Could not calculate GroupCallID")
                return false
            }
            
            guard groupCallActor.callID == proposedCallID else {
                return false
            }
            
            guard groupCallActor.sfuBaseURL == proposedGroupCall.sfuBaseURL else {
                return false
            }
            // TODO: (IOS-3857) Logging
            DDLogNotice("[GroupCall] We already have calls running in \(proposedGroupCall.hexCallID)")
            
            return true
        }.isEmpty)
    }
    
    func groupCalls(in group: GroupCallsThreemaGroupModel) -> [GroupCallActor] {
        currentlyRunningGroupCalls.filter { $0.group == group }
    }
    
    public func joinCall(
        in group: GroupCallsThreemaGroupModel,
        intent: GroupCallUserIntent
    ) async -> (Bool, GroupCallViewModel?) {
        DDLogWarn("[GroupCall] Creating call in \(group.groupID)")
        startPeriodicCheckIfNeeded()
        
        let candidates = currentlyRunningGroupCalls.filter { $0.group == group }
        
        try? await checkCallsStillRunning()
        
        if candidates.isEmpty {
            return (false, nil)
        }
        else if candidates.count == 1, let first = candidates.first, await first.joinState() == .runningLocal {
            let viewModel = await first.viewModel
            DDLogNotice(
                "[GroupCall] [GCDEBing view model for \(first.logIdentifier) \(Unmanaged.passUnretained(viewModel).toOpaque())"
            )
            return (true, viewModel)
        }
        
        guard let candidate = try? await getCurrentlyChosenCall(in: group, from: currentlyRunningGroupCalls) else {
            return (false, nil)
        }
        
        do {
            try await candidate.join(intent: intent)
            globalGroupCallObserver.stateContinuation.yield(candidate.group)
            let viewModel = await candidate.viewModel
            // TODO: (IOS-3857) Logging
            DDLogWarn(
                "[GroupCall] [GCDEBing view model for \(candidate.logIdentifier) \(Unmanaged.passUnretained(viewModel).toOpaque())"
            )
            
            return (true, viewModel)
        }
        catch {
            DDLogError("We have encountered an error: \(error)")
            assertionFailure()
            return (false, nil)
        }
    }
    
    /// Creates a group call for the given parameter
    /// - Parameters:
    ///   - group: Group to create call for
    ///   - localIdentity: ThreemaID of the local identity
    /// - Returns: Start message ????
    public func createCall(
        in group: GroupCallsThreemaGroupModel,
        localIdentity: ThreemaID
    ) async throws -> CspE2e_GroupCallStart {
        startPeriodicCheckIfNeeded()
        
        // TODO: (IOS-3857) Logging
        DDLogWarn("[GroupCall] Creating call in \(group.groupID)")
        let token = try await dependencies.httpHelper.sfuCredentials()
        let gck = dependencies.groupCallCrypto.randomBytes(of: 32)
        
        // We now have a start date
        // Check whether there is already a group call running in this group and if it is older than this call
        let thisGroupCurrentlyRunningGroupCalls = currentlyRunningGroupCalls.filter { $0.group == group }
        
        guard try await (getCurrentlyChosenCall(in: group, from: Set(thisGroupCurrentlyRunningGroupCalls))) == nil
        else {
            DDLogError("[GroupCall] There are currently other calls considered to be running in this group")
            throw GroupCallManagerError.CannotJoinAlreadyInACall
        }
        
        let actor = try GroupCallActor(
            localIdentity: localIdentity,
            groupModel: group,
            sfuBaseURL: token.sfuBaseURL,
            gck: gck,
            dependencies: dependencies
        )
        
        currentlyRunningGroupCalls.insert(actor)
        globalGroupCallObserver.stateContinuation.yield(group)
        
        try await actor.join(intent: .create)
        
        // Preliminary start date
        await actor.set(callStartDate: Date())
        
        Task {
            do {
                try await dependencies.groupCallSystemMessageAdapter.post(.groupCallStarted, in: group)
            }
            catch {
                DDLogError("[GroupCall] An error occurred when attempting to post a system message \(error)")
            }
        }
        
        var startMessage = CspE2e_GroupCallStart()
        startMessage.protocolVersion = GroupCallConfiguration.ProtocolDefines.protocolVersion
        startMessage.gck = gck
        startMessage.sfuBaseURL = token.sfuBaseURL
        
        return startMessage
    }
    
    public func viewModel(for group: GroupCallsThreemaGroupModel) async -> GroupCallViewModel? {
        try? await getCurrentlyChosenCall(in: group, from: currentlyRunningGroupCalls)?.viewModel
    }
    
    public func viewModelForCurrentlyJoinedGroupCall() async -> GroupCallViewModel? {
        for call in currentlyRunningGroupCalls {
            if await !call.hasEnded {
                return await call.viewModel
            }
        }
        return nil
    }
}

extension GroupCallManager {
    public func getCallID(in groupModel: GroupCallsThreemaGroupModel) -> String {
        currentlyRunningGroupCalls.filter { $0.group == groupModel }.first!.callID.bytes.hexEncodedString()
    }
}

extension GroupCallManager {
    private func checkCallsStillRunning() async throws {
        DDLogNotice("[GroupCall] [PeriodicCleanup] \(#function)")
        
        if let currentCallCheckTask {
            DDLogNotice("[GroupCall] [PeriodicCleanup] \(#function) Skip")
            try await currentCallCheckTask.value
            
            return
        }
        
        currentCallCheckTask = Task {
            defer { self.currentCallCheckTask = nil }
            DDLogNotice("[GroupCall] [PeriodicCleanup] \(#function) Start")
            defer { DDLogNotice("[GroupCall] [PeriodicCleanup] \(#function) Finished") }
            
            /// **Protocol Step: Periodic Refresh** 1. Let `currentlyRunningGroupCalls` be the list of group calls that
            /// are currently
            /// considered running within the group.
            
            /// **Protocol Step: Periodic Refresh** 2. Let `currentCalls` be a copy of `currentlyRunningGroupCalls`.
            /// Reset the token-refreshed mark of
            /// each call of calls (or simply scope it to the execution of these steps).
            let currentCalls = Array(currentlyRunningGroupCalls)
            
            /// **Protocol Step: Periodic Refresh** 3. For each call of `currentCalls`, run the following steps
            /// (labelled
            /// peek-call) concurrently and wait for them to return:
            for currentlyRunningGroupCall in currentCalls {
                // Check if we have been cancelled
                guard !Task.isCancelled else {
                    return
                }
                
                do {
                    /// **Protocol Step: Periodic Refresh** 3.1 to 3.2 in `periodicRefresh(for:_)`
                    switch try await periodicRefresh(for: currentlyRunningGroupCall) {
                    case .keep:
                        /// **Protocol Step: Periodic Refresh** 3.5 Reset the call's failed counter to 0.
                        await currentlyRunningGroupCall.resetFailedCounter()
                        continue
                        
                    case .remove:
                        await remove(currentlyRunningGroupCall)
                        
                        do {
                            let group = currentlyRunningGroupCall.group
                            try await dependencies.groupCallSystemMessageAdapter.post(.groupCallEnded, in: group)
                        }
                        catch {
                            if let error = error as? GroupCallSystemMessageAdapterError {
                                DDLogError(
                                    "[GroupCall] An error occurred when attempting to post a system message, error: \(error)"
                                )
                            }
                        }
                        
                    case .retry:
                        /// **Protocol Step: Periodic Refresh** 3.3.1. Refresh the SFU Token. If the SFU Token refresh
                        /// fails or does not yield an SFU Token within 10s, remove call from calls and abort the
                        /// peek-call sub-steps.
                        let task = Task {
                            try await dependencies.httpHelper.sfuCredentials()
                        }
                        
                        switch try await Task.timeout(task, 10) {
                        case .error(_), .timeout:
                            // TODO: Do we need to handle network failures here?
                            await remove(currentlyRunningGroupCall)
                            
                        case .result:
                            /// **Protocol Step: Periodic Refresh** 3.3.3. Restart the peek-call sub-steps for this
                            /// call.
                            switch try await periodicRefresh(for: currentlyRunningGroupCall) {
                            case .remove, .retry:
                                await remove(currentlyRunningGroupCall)
                            case .keep:
                                await currentlyRunningGroupCall.resetFailedCounter()
                                continue
                            }
                        }
                    }
                }
                catch {
                    // Any relevant network errors have already been handled by the peek steps
                    DDLogError("[GroupCall] An error occurred \(error)")
                    assertionFailure()
                }
                
                /// **Protocol Step: Periodic Refresh** 3.6. If the protocol version of the call is not supported,
                /// remove call from calls, log a warning that a group call with an unsupported version is currently
                /// running and abort the peek-call sub-steps.
                
                if currentlyRunningGroupCall.protocolVersion > ProtocolDefines.PROTOCOL_VERSION {
                    DDLogWarn(
                        "[GroupCall] Protocol version of currently running group call (\(currentlyRunningGroupCall.protocolVersion)) is not the same as supported version (\(ProtocolDefines.PROTOCOL_VERSION))."
                    )
                    await remove(currentlyRunningGroupCall)
                }
            }
            
            /// **Protocol Step: Periodic Refresh** 4. If running is empty, cancel the timer to periodically re-run the
            /// Group Call Refresh Steps of this group. Otherwise, restart or schedule the timer to re-run
            /// the Group Call Refresh Steps of this group in 10s.
            guard !currentlyRunningGroupCalls.isEmpty else {
                return
            }
            
            for group in Set(currentCalls.map(\.group)) {
                // TODO: We could speed this up with a task group
                try await getCurrentlyChosenCall(in: group, from: Set(currentCalls))
            }
            
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] \(#function) We have currently \(currentlyRunningGroupCalls.count) calls running"
            )
        }
    }
    
    private func remove(_ groupCallActor: GroupCallActor) async {
        _ = await groupCallActor.stopCall()
        await groupCallActor.prepareForRemove()
        currentlyRunningGroupCalls.remove(groupCallActor)
        
        guard let databaseDelegate else {
            DDLogError("[GroupCalls] [Peek Steps] We do not have a database delegate set")
            return
        }
        
        databaseDelegate.removeFromStoredCalls(groupCallActor.proposedGroupCall)
    }
    
    private nonisolated func periodicRefresh(for groupCallActor: GroupCallActor) async throws -> PeriodicRefreshResult {
        /// **Protocol Step: Periodic Refresh** 3.1 to 3.2 in `stillRunning()`
        let stillRunning = try await groupCallActor.stillRunning()
        
        switch stillRunning {
        case .running:
            return .keep
            
        case .ended:
            /// **Protocol Step: Periodic Refresh** 3.4.2. If the received status code is 404, remove call from running
            /// and abort the peek-call sub-steps.
            return .remove
            
        case .timeout, .invalid:
            /// **Protocol Step: Periodic Refresh** 3.4: If the server could not be reached or the received status code
            /// is not 200 or if the Peek response could not be decoded:
            
            /// **Protocol Step: Periodic Refresh** 3.4.3 If the call's failed counter is >= 3 and the call was received
            /// more than 10h ago, remove call from running and abort the peek-call sub-steps.
            guard await groupCallActor.failedCounter < 3, !groupCallActor.receivedMoreThan10HoursAgo else {
                return .remove
            }
            
            /// **Protocol Step: Periodic Refresh** 3.4.4. Increase the failed counter for call by 1 and abort the
            /// peek-call sub-steps.
            await groupCallActor.incrementFailedCounter()
            return .retry
            
        case .invalidToken:
            /// **Protocol Step: Periodic Refresh** 3.3 If the received status code for call is 401 and call is not
            /// marked with token-refreshed:
            guard await !(groupCallActor.tokenRefreshed) else {
                return .remove
            }
            
            /// **Protocol Step: Periodic Refresh** 3.3.1. Refresh the SFU Token. If the SFU Token refresh fails or
            /// does not yield an SFU Token within 10s, remove call from calls and abort the peek-call sub-steps.
            
            // This protocol step will be executed in the caller.
            // Note that this should never actually happen with our implementation. We automatically fetch the
            // authentication token before making any API call if it will expire soon.
            
            /// **Protocol Step: Periodic Refresh** 3.3.2: Mark the call as token-refreshed.
            await groupCallActor.setTokenRefreshed()
            return .retry
        }
    }
    
    @discardableResult
    internal func getCurrentlyChosenCall(
        in group: GroupCallsThreemaGroupModel,
        from currentCalls: Set<GroupCallActor>
    ) async throws -> GroupCallActor? {
        var currentlyChosenCall: GroupCallActor?
        
        let thisGroupGroupCalls = currentCalls.filter { $0.group == group }
        
        /// **Protocol Step: Periodic Refresh** 5. Let chosen-call be any call of calls with the highest started_at
        /// value (i.e. the most recently created call) as provided by the peek result.
        for groupCall in thisGroupGroupCalls {
            if currentlyChosenCall == nil {
                if await groupCall.exactCallStartDate != nil {
                    currentlyChosenCall = groupCall
                }
                continue
            }
            
            guard let innerChosenCall = currentlyChosenCall else {
                let msg =
                    "[GroupCall] This never happens because we always either set `currentlyChosenCall` above or call `continue`"
                assertionFailure(msg)
                DDLogError(msg)
                return nil
            }
            
            guard let currentStartDate = await innerChosenCall.exactCallStartDate else {
                continue
            }
            guard let newStartDate = await groupCall.exactCallStartDate else {
                continue
            }
            
            DDLogNotice(
                "[GroupCall] [Periodic Refresh] [Peek Steps] Previously chosen call \(innerChosenCall.logIdentifier.prefix(5)) has start date \(currentStartDate)"
            )
            DDLogNotice(
                "[GroupCall] [Periodic Refresh] [Peek Steps] Potential new chosen call \(groupCall.logIdentifier.prefix(5)) has start date \(newStartDate)"
            )
            
            if currentStartDate < newStartDate {
                currentlyChosenCall = groupCall
                
                DDLogNotice(
                    "[GroupCall] [Periodic Refresh] [Peek Steps] Choose call \(innerChosenCall.logIdentifier.prefix(5)) with start date \(newStartDate)"
                )
            }
            else {
                DDLogNotice(
                    "[GroupCall] [Periodic Refresh] [Peek Steps] Choose call \(innerChosenCall.logIdentifier.prefix(5)) with start date \(currentStartDate)"
                )
            }
        }
        
        var chosenCallDidChange = false
        for groupCall in thisGroupGroupCalls {
            if groupCall == currentlyChosenCall {
                chosenCallDidChange = await groupCall.setIsChosenCall() || chosenCallDidChange
            }
            else {
                chosenCallDidChange = await groupCall.removeIsChosenCall() || chosenCallDidChange
            }
        }
        
        guard let currentlyChosenCall else {
            /// **Protocol Step: Periodic Refresh** 6. If chosen-call is not defined, signal that no group call is
            /// currently running within the group, abort these steps and return chosen-call.
            
            // TODO: (IOS-????) Causes loop to refresh buttons in cv and ctvc
            // globalGroupCallObserver.stateContinuation.yield(group)
            return nil
        }
        
        // TODO: Only signal here if group call wasn't chosen call before
        /// **Protocol Step: Periodic Refresh** 7. Signal chosen-call as the currently running group call within the
        /// group.
        if chosenCallDidChange {
            globalGroupCallObserver.stateContinuation.yield(group)
        }
        
        var wasJoiningCall = false
        var wasParticipatingInCall = false
        DDLogNotice(
            "[GroupCall] [Peek Steps] Choosen Call \(String(describing: currentlyChosenCall.logIdentifier.prefix(5)))"
        )
        for groupCall in thisGroupGroupCalls.filter({ $0 != currentlyChosenCall }) {
            if await groupCall.isChosenCall {
                let msg =
                    "[GroupCall] We may only have one chosen call for each group. But despite resetting it just above we still have multiple."
                assertionFailure(msg)
                DDLogError(msg)
                return nil
            }
            
            switch await groupCall.joinState() {
            case .joining:
                wasJoiningCall = true
                DDLogNotice("[GroupCall] [Peek Steps] Stopping Call \(groupCall.logIdentifier.prefix(5))")
                _ = await groupCall.stopCall()
            case .runningLocal:
                wasParticipatingInCall = true
                _ = await groupCall.stopCall()
                DDLogNotice("[GroupCall] [Peek Steps] Stopping Call \(groupCall.logIdentifier.prefix(5))")
            case .notRunningLocal:
                continue
            }
            
            await groupCall.assertNotConnected()
        }
        
        /// **Protocol Step: Periodic Refresh** 8. If the Group Call Join Steps are currently running with a different
        /// (or new) group call
        /// than chosen-call, cancel and restart the Group Call Join Steps asynchronously with the same intent but with
        /// the chosen-call.
        if wasJoiningCall {
            assert(!wasParticipatingInCall)
            try? await currentlyChosenCall.join(intent: .join)
            await uiDelegate?.showViewController(for: currentlyChosenCall.viewModel)
        }
        /// **Protocol Step: Periodic Refresh** 9. If the user is currently participating in a group call of this group
        /// that is different to
        /// chosen-call, exit the running group call and run the Group Call Join Steps asynchronously with the intent to
        /// only join chosen-call.
        else if wasParticipatingInCall {
            assert(!wasJoiningCall)
            try? await currentlyChosenCall.join(intent: .join)
            await uiDelegate?.showViewController(for: currentlyChosenCall.viewModel)
        }
        
        // **Protocol Step ** 10. Return chosen-call.
        return currentlyChosenCall
    }
}
