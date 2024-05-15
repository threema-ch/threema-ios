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
import Combine
import CryptoKit
import Foundation
import ThreemaEssentials
import ThreemaProtocols
import WebRTC

public protocol GroupCallManagerDatabaseDelegateProtocol: AnyObject, Sendable {
    func removeFromStoredCalls(_ groupCall: ProposedGroupCall)
}

/// Handles all group calls that we know of.
/// Periodically checks whether calls are still running.
///
/// In the app this is used through the `GlobalGroupCallsManagerSingleton` class.
public final actor GroupCallManager {
    // MARK: - Nested Types

    fileprivate enum PeriodicRefreshResult {
        case keep
        case remove
        case retry
    }
    
    // MARK: - Private Properties

    private let dependencies: Dependencies
    private let localContactModel: ContactModel
    
    private var isCurrentlyJoiningOrJoinedCall = false
    private var groupsWithCurrentlyRunningGroupCalls = [GroupIdentity: Set<GroupCallActor>]()
    private var currentlyJoiningOrJoinedCall: GroupCallActor? {
        didSet {
            isCurrentlyJoiningOrJoinedCall = currentlyJoiningOrJoinedCall != nil
        }
    }
    
    private var periodicCallCheckTask: Task<Void, Never>?
    private var isPeriodicRefreshRunning = false

    // MARK: - Delegation
    
    private weak var databaseDelegate: GroupCallManagerDatabaseDelegateProtocol?
    public func set(databaseDelegate: GroupCallManagerDatabaseDelegateProtocol) {
        self.databaseDelegate = databaseDelegate
    }
    
    private weak var singletonDelegate: GroupCallManagerSingletonDelegate?
    public func set(singletonDelegate: GroupCallManagerSingletonDelegate) {
        self.singletonDelegate = singletonDelegate
    }
    
    // MARK: - Lifecycle
    
    public init(
        dependencies: Dependencies,
        localContactModel: ContactModel
    ) {
        self.dependencies = dependencies
        self.localContactModel = localContactModel
    }
    
    // MARK: - Update Functions
    
    /// Handles a new call message, either freshly received or loaded from DB
    /// - Parameters:
    ///   - proposedGroupCall: Proposed call
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
            groupIdentity: proposedGroupCall.groupRepresentation.groupIdentity,
            groupName: proposedGroupCall.groupRepresentation.groupName
        )
        
        do {
            let newGroupCall = try GroupCallActor(
                localContactModel: localContactModel,
                groupModel: groupModel,
                sfuBaseURL: proposedGroupCall.sfuBaseURL,
                gck: proposedGroupCall.gck,
                actorDelegate: self,
                dependencies: dependencies
            )
            
            addGroupCall(newGroupCall)
            
            try await refreshRunningGroupCalls(in: groupModel.groupIdentity)
            
            switch creatorOrigin {
            case let .remote(threemaID):
                try await dependencies.groupCallSystemMessageAdapter.post(
                    .groupCallStartedBy(threemaID),
                    in: groupModel
                )
                showIncomingGroupCallNotification(groupModel: groupModel, senderThreemaID: threemaID)
            case .local:
                try await dependencies.groupCallSystemMessageAdapter.post(
                    .groupCallStarted,
                    in: groupModel
                )
            case .db:
                break
            }
            
            // TODO: (IOS-3857) Logging
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] After adding \(newGroupCall.logIdentifier). We have currently \(groupsWithCurrentlyRunningGroupCalls.keys.count) groups with running calls"
            )
        }
        catch let error as GroupCallSystemMessageAdapterError {
            DDLogError("[GroupCall] An error occurred when attempting to post a system message \(error)")
        }
        catch {
            DDLogError("[GroupCall] An error occurred when adding a new group call \(error)")
        }
    }
    
    /// Creates a new call in a given group or joins it if its already running.
    /// - Parameters
    ///   - group: `GroupCallsThreemaGroupModel` of desired group
    ///   - localIdentity: ThreemaID of the local identity
    public func createOrJoinCall(
        in group: GroupCallsThreemaGroupModel,
        with intent: GroupCallUserIntent
    ) async throws {
        
        // If we already are in a call in this group, we return to just show the view
        guard currentlyJoiningOrJoinedCall?.group != group else {
            return
        }
        
        // If user tries to create call for another group, but another call is running, throw.
        guard !isCurrentlyJoiningOrJoinedCall else {
            throw GroupCallError.alreadyInCall
        }
        
        isCurrentlyJoiningOrJoinedCall = true
        
        /// **Protocol Step: Create or Join (1.)**
        /// 1. Let intent be the user's intent, i.e. to either only join or create or join a group call.
        
        /// 2. Refresh the SFU Token if necessary. If the SFU Token refresh fails within 10s, abort these steps and
        /// notify the user.
        guard let refreshedToken = try await dependencies.httpHelper.refreshTokenWithTimeout(10) else {
            throw GroupCallError.creationError
        }
        
        /// 3. Run the Group Call Refresh Steps for the respective group and let call be the result.
        startPeriodicCheckIfNeeded()
        let callsInGroup = groupsWithCurrentlyRunningGroupCalls[group.groupIdentity]
        var runningOrCreatedCall = try await getCurrentlyChosenCall(from: callsInGroup)
        
        // If we have a current call, we re-check if the call is still running, if not we reset the local state and show
        // an error
        if let runningOrCreatedCall {
            guard try await runningOrCreatedCall.stillRunning() != .ended else {
                currentlyJoiningOrJoinedCall = nil
                await remove(runningOrCreatedCall)
                throw GroupCallError.endedInMeantime
            }
        }
        else {
            /// 4. If call is undefined and intent is to only join, abort these steps and notify the user that no group
            /// call
            /// is running / the group call is no longer running.
            if intent == .join {
                throw GroupCallError.joinError
            }
            /// 5. If call is undefined, create (but don't send) a GroupCallStart message, apply it to call and mark
            /// call as new.
            runningOrCreatedCall = try await createCall(in: group, token: refreshedToken)
        }
        
        currentlyJoiningOrJoinedCall = runningOrCreatedCall
        
        guard let runningOrCreatedCall else {
            assertionFailure("[GroupCall] This should never happen.")
            throw GroupCallError.creationError
        }
        
        /// 6. Run the Group Call Join Steps with the intent and call.
        try await runningOrCreatedCall.join(intent: intent)
    }
    
    public func viewControllerForCurrentlyJoinedGroupCall() async -> GroupCallViewController? {
        guard let viewModel = await currentlyJoiningOrJoinedCall?.viewModel else {
            return nil
        }
        return await GroupCallViewController(viewModel: viewModel, dependencies: dependencies)
    }
    
    // MARK: - Private functions
    
    private func addGroupCall(_ call: GroupCallActor) {
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] Add call \(call.logIdentifier)")
        if var existingCallsInGroup = groupsWithCurrentlyRunningGroupCalls[call.group.groupIdentity] {
            existingCallsInGroup.insert(call)
            groupsWithCurrentlyRunningGroupCalls[call.group.groupIdentity] = existingCallsInGroup
        }
        else {
            groupsWithCurrentlyRunningGroupCalls[call.group.groupIdentity] = Set(arrayLiteral: call)
        }
    }
    
    private func removeGroupCall(_ call: GroupCallActor) {
        guard var existingCallsInGroup = groupsWithCurrentlyRunningGroupCalls[call.group.groupIdentity] else {
            DDLogNotice("[GroupCall] Removing call with \(call.logIdentifier) failed, not found.")
            return
        }
        DDLogNotice("[GroupCall] Removing call with \(call.logIdentifier)")

        existingCallsInGroup.remove(call)
        if existingCallsInGroup.isEmpty {
            groupsWithCurrentlyRunningGroupCalls[call.group.groupIdentity] = nil
            return
        }
        groupsWithCurrentlyRunningGroupCalls[call.group.groupIdentity] = existingCallsInGroup
    }
    
    private func groupCalls(in group: GroupCallsThreemaGroupModel) -> [GroupCallActor] {
        Array(groupsWithCurrentlyRunningGroupCalls[group.groupIdentity] ?? [])
    }
    
    private func createCall(
        in group: GroupCallsThreemaGroupModel,
        token: SFUToken
    ) async throws -> GroupCallActor {
        let gck = dependencies.groupCallCrypto.randomBytes(of: 32)
        
        let createdCall = try GroupCallActor(
            localContactModel: localContactModel,
            groupModel: group,
            sfuBaseURL: token.sfuBaseURL,
            gck: gck,
            actorDelegate: self,
            dependencies: dependencies
        )
        await createdCall.createStartMessage(token: token, gck: gck)

        return createdCall
    }
    
    private func updateBanner(for call: GroupCallActor) {
        Task {
            let buttonAndBannerUpdate = await GroupCallBannerButtonUpdate(actor: call, hideComponent: false)
            singletonDelegate?.updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: buttonAndBannerUpdate)
        }
    }
    
    private func showIncomingGroupCallNotification(
        groupModel: GroupCallsThreemaGroupModel,
        senderThreemaID: ThreemaIdentity
    ) {
        Task.detached {
            await self.singletonDelegate?.showIncomingGroupCallNotification(
                groupModel: groupModel,
                senderThreemaID: senderThreemaID
            )
        }
    }
}

extension GroupCallManager {
    public func getCallID(in groupModel: GroupCallsThreemaGroupModel) -> String? {
        groupsWithCurrentlyRunningGroupCalls[groupModel.groupIdentity]?.first?.callID.bytes.hexEncodedString()
    }
}

extension GroupCallManager {
    
    private func startPeriodicCheckIfNeeded() {
        guard periodicCallCheckTask == nil else {
            return
        }
        periodicCallCheckTask = Task { [weak self] in
            while let self {
                do {
                    try await self.runPeriodicRefresh()
                    try await Task.sleep(seconds: 10)
                }
                catch {
                    DDLogError(
                        "[GroupCall] [PeriodicCleanup] Cleanup Failed, removing `periodicCallCheckTask`. Error: \(error.localizedDescription)"
                    )
                    // We delay to prevent a fast running loop
                    try? await Task.sleep(seconds: 10)
                    await restartPeriodicCallCheckTask()
                }
            }
        }
    }
    
    private func restartPeriodicCallCheckTask() {
        periodicCallCheckTask?.cancel()
        periodicCallCheckTask = nil
        startPeriodicCheckIfNeeded()
    }
    
    private func runPeriodicRefresh() async throws {
        // We create a refresh task for each of the groups that have at least one running group call in them, and run
        // them concurrently.
        guard !isPeriodicRefreshRunning else {
            DDLogNotice("[GroupCall] [PeriodicCleanup] Refresh already running, skip.")
            return
        }
        
        DDLogNotice("[GroupCall] [PeriodicCleanup] Refresh started.")
        isPeriodicRefreshRunning = true
        
        await withThrowingTaskGroup(of: Void.self) { group in
            for groupIdentity in groupsWithCurrentlyRunningGroupCalls.keys {
                group.addTask {
                    try await self.refreshRunningGroupCalls(in: groupIdentity)
                }
            }
        }
        
        isPeriodicRefreshRunning = false
        DDLogNotice("[GroupCall] [PeriodicCleanup] Refresh ended.")
    }
    
    private func refreshRunningGroupCalls(in group: GroupIdentity) async throws {
        /// **Protocol Step: Periodic Refresh (1.)**
        /// 1. Let `running` (`currentlyRunningGroupCalls`) be the list of group calls that are currently considered
        /// running within the group.
        
        /// **Protocol Step: Periodic Refresh (2.)**
        /// 2. Let `calls` (`currentCalls`) be a copy of `running` (`currentlyRunningGroupCalls`). Reset the
        /// _token-refreshed_ mark of each `call` of `calls` (or simply scope it to the execution of these steps).
        ///
        /// *Note:* Resetting the _token-refreshed_ mark is not needed, since we refresh the token anyways each time
        /// before making any API call if it will expire soon.
        guard let currentCalls = groupsWithCurrentlyRunningGroupCalls[group], !currentCalls.isEmpty else {
            return
        }
        DDLogNotice(
            "[GroupCall] [PeriodicCleanup] Refreshing calls in group with identity \(group.id.hexEncodedString()), number of currently running calls: \(currentCalls.count)."
        )

        await withThrowingTaskGroup(of: Void.self) { group in
            /// **Protocol Step: Periodic Refresh (3.)**
            /// 3. For each `call` of `calls` (`currentCalls`), run the following steps (labelled _peek-call_)
            /// concurrently and wait for them to return:
            for call in currentCalls {
                group.addTask {
                    await self.peekCall(call)
                }
            }
        }
        
        /// **Protocol Step: Periodic Refresh** 3.7. (`call` is kept in `calls` and in `running`
        /// (`currentlyRunningGroupCalls`).
        
        /// **Protocol Step: Periodic Refresh (4.)**
        /// 4. If `running` (`currentlyRunningGroupCalls`) is empty, cancel the timer to periodically re-run the
        /// _Group Call Refresh Steps_ of this group. Otherwise, restart or schedule the timer to re-run the _Group
        /// Call Refresh Steps_ of this group in 10s.
        guard let currentCalls = groupsWithCurrentlyRunningGroupCalls[group], !currentCalls.isEmpty else {
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] There are no more calls running in group with identity \(group.id.hexEncodedString())."
            )
            return
        }
        
        // The full task will be tried to rerun by `GroupCallManager` after 10s or wait for the current running task
        // if it hasn't completed
        if let actor = try await getCurrentlyChosenCall(from: currentCalls) {
            let buttonAndBannerUpdate = await GroupCallBannerButtonUpdate(actor: actor, hideComponent: false)
            
            singletonDelegate?
                .updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: buttonAndBannerUpdate)
        }
        
        DDLogNotice(
            "[GroupCall] [PeriodicCleanup] Refresh completed for calls running in group with identity \(group.id.hexEncodedString()), there are still \(currentCalls.count) calls running."
        )
    }
    
    private func peekCall(_ groupCall: GroupCallActor) async {
        // Check if we have been cancelled
        guard !Task.isCancelled else {
            return
        }

        DDLogNotice("[GroupCall] [PeriodicCleanup] Peeking call: \(groupCall.logIdentifier.prefix(5))")
        do {
            /// **Protocol Step: Periodic Refresh (3.1. - 3.4.)**
            switch try await periodicRefresh(for: groupCall) {
            case .keep:
                return
                
            case .remove:
                await remove(groupCall)
                
                do {
                    let group = groupCall.group
                    try await dependencies.groupCallSystemMessageAdapter.post(.groupCallEnded, in: group)
                }
                catch {
                    if let error = error as? GroupCallSystemMessageAdapterError {
                        DDLogError(
                            "[GroupCall] An error occurred when attempting to post a system message, error: \(error)"
                        )
                    }
                }
                return
                
            // TODO: (IOS-4070) This should probably not exist, we should retry in periodic refresh directly, for legibility.
            case .retry:
                /// **Protocol Step: Periodic Refresh** 3.3.1. Refresh the SFU Token. If the SFU Token refresh
                /// fails or does not yield an SFU Token within 10s, remove call from calls and abort the
                /// peek-call sub-steps.
                let task = Task {
                    try await dependencies.httpHelper.sfuCredentials()
                }
                
                switch try await Task.timeout(task, 10) {
                case let .error(error):
                    await remove(groupCall)
                    if let error {
                        throw error
                    }
                    
                case .timeout:
                    await remove(groupCall)
                    
                case .result:
                    /// **Protocol Step: Periodic Refresh** 3.3.3. Restart the peek-call sub-steps for this
                    /// call.
                    switch try await periodicRefresh(for: groupCall) {
                    case .remove, .retry:
                        await remove(groupCall)
                    case .keep:
                        await groupCall.resetFailedCounter()
                        return
                    }
                }
            }
        }
        catch {
            // Any relevant network errors have already been handled by the peek steps
            // The peek might be cancelled due to a new one starting, but we do not want to remove the call in this
            // case.
            if !(error is CancellationError) {
                assertionFailure("[GroupCall] An error occurred, removing call: \(error)")
                DDLogError("[GroupCall] An error occurred, removing call: \(error)")
                await remove(groupCall)
            }
            return
        }
        
        /// **Protocol Step: Periodic Refresh** 3.5 Reset the call's failed counter to 0.
        await groupCall.resetFailedCounter()
        
        /// **Protocol Step: Periodic Refresh** 3.6. If the protocol version of the call is not supported,
        /// remove call from calls, log a warning that a group call with an unsupported version is currently
        /// running and abort the peek-call sub-steps.
        
        if groupCall.protocolVersion > ProtocolDefines.protocolVersion {
            DDLogWarn(
                "[GroupCall] Protocol version of currently running group call (\(groupCall.protocolVersion)) is not the same as supported version (\(ProtocolDefines.protocolVersion))."
            )
            await remove(groupCall)
        }
    }
    
    private func remove(_ call: GroupCallActor) async {
        await call.leaveCall()
        await call.teardown()
        removeGroupCall(call)
        
        try? await refreshRunningGroupCalls(in: call.group.groupIdentity)
        
        guard let databaseDelegate else {
            DDLogError("[GroupCalls] [Peek Steps] We do not have a database delegate set")
            return
        }
        
        databaseDelegate.removeFromStoredCalls(call.proposedGroupCall)
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
            
        case .timeout:
            // This means we did not receive an answer within 5s, see Periodic Refresh step 3.2.
            return .remove
            
        case .invalid:
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
        from currentCalls: Set<GroupCallActor>?
    ) async throws -> GroupCallActor? {
        var currentlyChosenCall: GroupCallActor?
        
        guard let thisGroupGroupCalls = currentCalls else {
            return nil
        }
        
        /// **Protocol Step: Periodic Refresh** 5. Let chosen-call be any call of calls with the highest started_at
        /// value (i.e. the most recently created call) as provided by the peek result.
        for groupCall in thisGroupGroupCalls {
            if currentlyChosenCall == nil {
                if await groupCall.exactCreationTimestamp != nil {
                    currentlyChosenCall = groupCall
                }
                continue
            }
            
            guard let innerChosenCall = currentlyChosenCall else {
                let msg =
                    "[GroupCall] This never happens because we always either set `currentlyChosenCall` above or call `continue`"
                assertionFailure(msg)
                DDLogError("\(msg)")
                return nil
            }
            
            guard let currentCreationTimestamp = await innerChosenCall.exactCreationTimestamp else {
                continue
            }
            guard let newStartCreationTimestamp = await groupCall.exactCreationTimestamp else {
                continue
            }
            
            DDLogNotice(
                "[GroupCall] [Periodic Refresh] [Peek Steps] Previously chosen call \(innerChosenCall.logIdentifier.prefix(5)) has creation timestamp \(currentCreationTimestamp)"
            )
            DDLogNotice(
                "[GroupCall] [Periodic Refresh] [Peek Steps] Potential new chosen call \(groupCall.logIdentifier.prefix(5)) has creation timestamp \(newStartCreationTimestamp)"
            )
            
            if currentCreationTimestamp < newStartCreationTimestamp {
                currentlyChosenCall = groupCall
                
                DDLogNotice(
                    "[GroupCall] [Periodic Refresh] [Peek Steps] Choose call \(innerChosenCall.logIdentifier.prefix(5)) with screation timestamp \(newStartCreationTimestamp)"
                )
            }
            else {
                DDLogNotice(
                    "[GroupCall] [Periodic Refresh] [Peek Steps] Choose call \(innerChosenCall.logIdentifier.prefix(5)) with creation timestamp \(currentCreationTimestamp)"
                )
            }
        }
        
        /// **Protocol Step: Periodic Refresh (6.)**
        /// 6. If `chosen-call` is not defined, signal that no group call is currently running within the group, abort
        /// these steps and return `chosen-call`.
        guard let currentlyChosenCall else {
            return nil
        }
        
        /// **Protocol Step: Periodic Refresh (7.)**
        /// 7. Signal `chosen-call` as the currently running group call within the group.
        
        // Check if call changed and set this on the group call actor
        var chosenCallDidChange = false
        for groupCall in thisGroupGroupCalls {
            if groupCall == currentlyChosenCall {
                chosenCallDidChange = await groupCall.setIsChosenCall() || chosenCallDidChange
            }
            else {
                chosenCallDidChange = await groupCall.removeIsChosenCall() || chosenCallDidChange
            }
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
                await groupCall.forceLeaveCall()
                await remove(groupCall)
                currentlyJoiningOrJoinedCall = nil
                DDLogNotice("[GroupCall] [Peek Steps] Stopping running call \(groupCall.logIdentifier.prefix(5))")
                
            case .joined:
                wasParticipatingInCall = true
                await groupCall.forceLeaveCall()
                await remove(groupCall)
                currentlyJoiningOrJoinedCall = nil
                DDLogNotice("[GroupCall] [Peek Steps] Stopping joined call \(groupCall.logIdentifier.prefix(5))")
                
            case .notJoined:
                continue
            }
            
            await groupCall.assertNotConnected()
        }
        
        /// **Protocol Step: Periodic Refresh (8.)**
        /// 8. If the _Group Call Join Steps_ are currently running with a different (or new) group call than
        /// `chosen-call`, cancel and restart the _Group Call Join Steps_ asynchronously with the same `intent` but with
        /// the `chosen-call`.
        if wasJoiningCall {
            assert(!wasParticipatingInCall)
            DDLogNotice("[GroupCall] [Peek Steps] Joining call \(currentlyChosenCall.logIdentifier.prefix(5))")
            try await currentlyChosenCall.join(intent: .join)
            currentlyJoiningOrJoinedCall = currentlyChosenCall
            let viewController = await GroupCallViewController(
                viewModel: currentlyChosenCall.viewModel,
                dependencies: dependencies
            )
            singletonDelegate?.showGroupCallViewController(viewController: viewController)
        }
        /// **Protocol Step: Periodic Refresh (9.)**
        /// 9. If the user is currently participating in a group call of this group that is different to `chosen-call`,
        /// exit the running group call and run the _Group Call Join Steps_ asynchronously with the `intent` to _only
        /// join_ `chosen-call`.
        else if wasParticipatingInCall {
            DDLogNotice("[GroupCall] [Peek Steps] Joining call \(currentlyChosenCall.logIdentifier.prefix(5))")
            assert(!wasJoiningCall)
            try await currentlyChosenCall.join(intent: .join)
            currentlyJoiningOrJoinedCall = currentlyChosenCall
            let viewController = await GroupCallViewController(
                viewModel: currentlyChosenCall.viewModel,
                dependencies: dependencies
            )
            singletonDelegate?.showGroupCallViewController(viewController: viewController)
        }
        
        /// **Protocol Step: Periodic Refresh (10.)**
        /// 10. Return `chosen-call`.
        return currentlyChosenCall
    }
}

// MARK: - GroupCallActorManagerDelegate

extension GroupCallManager: GroupCallActorManagerDelegate {
    func startRefreshSteps() async {
        startPeriodicCheckIfNeeded()
    }
    
    func addToRunningGroupCalls(groupCall: GroupCallActor) async {
        addGroupCall(groupCall)
    }

    func removeFromRunningGroupCalls(groupCall: GroupCallActor) async {
        if groupCall == currentlyJoiningOrJoinedCall {
            currentlyJoiningOrJoinedCall = nil
        }
    }
    
    func updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: GroupCallBannerButtonUpdate) async {
        singletonDelegate?
            .updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: groupCallBannerButtonUpdate)
    }
    
    func sendStartCallMessage(_ wrappedMessage: WrappedGroupCallStartMessage) async throws {
        try await singletonDelegate?.sendStartCallMessage(wrappedMessage)
    }
    
    func refreshGroupCalls(in group: GroupIdentity) async {
        try? await refreshRunningGroupCalls(in: group)
    }
    
    func showGroupCallFullAlert(maxParticipants: Int?) async {
        await withCheckedContinuation { continuation in
            
            guard let singletonDelegate else {
                continuation.resume()
                return
            }
            
            singletonDelegate.showGroupCallFullAlert(maxParticipants: maxParticipants) {
                continuation.resume()
            }
        }
    }
}

extension GroupCallManager {
    /// Only use when running screenshots
    public func groupCallViewControllerForScreenshots(
        groupName: String,
        localID: String,
        participantThreemaIdentities: [ThreemaIdentity]
    ) async -> GroupCallViewController {
        
        let localParticipantInfo = dependencies.groupCallParticipantInfoFetcher.fetchInfoForLocalIdentity()
        let localParticipant = await ViewModelParticipant(
            id: ParticipantID(id: 0),
            identity: ThreemaIdentity(localID),
            name: dependencies.groupCallBundleUtil.localizedString(for: "me"),
            avatar: localParticipantInfo.avatar,
            idColor: localParticipantInfo.color,
            dependencies: dependencies
        )
        
        var participantsList = [localParticipant]
        
        for (index, participantThreemaIdentity) in participantThreemaIdentities.enumerated() {
            let participantInfo = dependencies.groupCallParticipantInfoFetcher
                .fetchInfo(id: participantThreemaIdentity.string)
            let participant = await ViewModelParticipant(
                id: ParticipantID(id: UInt32(index + 1)),
                identity: participantThreemaIdentities[index],
                name: participantInfo.displayName!,
                avatar: participantInfo.avatar,
                idColor: participantInfo.color,
                dependencies: dependencies
            )
            participantsList.append(participant)
        }
        
        let viewModel = GroupCallViewModel(
            screenshotGroupName: groupName,
            localParticipant: localParticipant,
            participantsList: participantsList
        )
        
        return await GroupCallViewController(
            viewModel: viewModel,
            dependencies: dependencies,
            isRunningForScreenShots: true
        )
    }
}
