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
/// In the app this is used through the `GlobalGroupCallManagerSingleton` class.
public final actor GroupCallManager {
    // MARK: - Nested Types

    fileprivate enum PeriodicRefreshResult {
        case keep
        case remove
        case retry
        // The peek did not succeed, but the call might still be running. It is kept and skipped for this round.
        case skip
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
    ///   - calledFromExtension: Wether we call this func in an extension context or not
    /// - Returns: `false` only if the SFU explicitly told us that the call is no longer running, `true` in every other
    ///            case including when the state could not be determined
    @discardableResult
    public func handleNewCallMessage(
        for proposedGroupCall: ProposedGroupCall,
        creatorOrigin: GroupCallCreatorOrigin,
        calledFromExtension: Bool
    ) async -> Bool {
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] [Message Processor] \(#function) with callID \(proposedGroupCall.hexCallID)")
        
        // As a precautionary measure, it is advisable to refrain from calling the startPeriodicCheckIfNeeded function
        // from the extension. This action will initiate a refresh timer that is not appropriate for execution
        // within the extension’s context.
        if !calledFromExtension {
            startPeriodicCheckIfNeeded()
        }

        let groupModel = proposedGroupCall.groupRepresentation

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

            // The call might have ended before we were able to process its start message. We only skip the incoming
            // call notification if the SFU explicitly told us that the call is no longer running; if we cannot
            // determine the state we notify, since missing a running call is worse than a notification for a call
            // that has just ended.
            let callMightBeRunning: Bool

            if calledFromExtension {
                // The refresh steps must not run in an extension context: they may remove calls and delete their
                // database entities, which the app would then never see. Peeking is read-only and thus safe.
                callMightBeRunning = await mightStillBeRunning(newGroupCall)
            }
            else {
                try await refreshRunningGroupCalls(in: groupModel.groupIdentity)
                callMightBeRunning = groupCalls(in: groupModel).contains(newGroupCall)
            }

            switch creatorOrigin {
            case let .remote(threemaID):
                // Started by ourselves on another device
                if threemaID == localContactModel.identity {
                    try await dependencies.groupCallSystemMessageAdapter.post(
                        .groupCallStarted(proposedGroupCall.startMessageReceiveDate),
                        in: groupModel
                    )
                }
                else {
                    try await dependencies.groupCallSystemMessageAdapter.post(
                        .groupCallStartedBy(threemaID, proposedGroupCall.startMessageReceiveDate),
                        in: groupModel
                    )

                    if callMightBeRunning {
                        showIncomingGroupCallNotification(groupModel: groupModel, senderThreemaID: threemaID)
                    }
                    else {
                        DDLogNotice(
                            "[GroupCall] Do not show a notification for call \(newGroupCall.callID) because it is no longer running"
                        )
                    }
                }
            case .local:
                try await dependencies.groupCallSystemMessageAdapter.post(
                    .groupCallStarted(proposedGroupCall.startMessageReceiveDate),
                    in: groupModel
                )
            case .db:
                break
            }
            
            // TODO: (IOS-3857) Logging
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] After adding \(newGroupCall.callID). We have currently \(groupsWithCurrentlyRunningGroupCalls.keys.count) groups with running calls"
            )

            return callMightBeRunning
        }
        catch let error as GroupCallSystemMessageAdapterError {
            DDLogError("[GroupCall] An error occurred when attempting to post a system message: \(error)")
            return true
        }
        catch {
            DDLogError("[GroupCall] An error occurred when adding a new group call: \(error)")
            return true
        }
    }
    
    /// Creates a new call in a given group or joins it if its already running.
    /// - Parameters
    ///   - group: `GroupCallThreemaGroupModel` of desired group
    ///   - localIdentity: ThreemaID of the local identity
    public func createOrJoinCall(
        in group: GroupCallThreemaGroupModel,
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

        // We need to reset `currentlyJoiningOrJoinedCall` if no call was created, e.g. we throw or exit early.
        defer {
            if currentlyJoiningOrJoinedCall == nil {
                isCurrentlyJoiningOrJoinedCall = false
            }
        }

        /// **Protocol Step: Create or Join (1.)**
        /// 1. Let intent be the user's intent, i.e. to either only join or create or join a group call.
        
        /// 2. Refresh the SFU Token if necessary. If the SFU Token refresh fails within 15s, abort these steps and
        /// notify the user.
        guard let refreshedToken = try await dependencies.httpHelper
            .refreshTokenWithTimeout(ProtocolDefines.tokenRefreshTimeout) else {
            isCurrentlyJoiningOrJoinedCall = false
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
            assertionFailure("[GroupCall] This should never happen")
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
        DDLogNotice("[GroupCall] Add call \(call.callID)")
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
            DDLogNotice("[GroupCall] Removing call with \(call.callID) failed, not found")
            return
        }
        DDLogNotice("[GroupCall] Removing call with \(call.callID)")

        existingCallsInGroup.remove(call)
        if existingCallsInGroup.isEmpty {
            groupsWithCurrentlyRunningGroupCalls[call.group.groupIdentity] = nil
            return
        }
        groupsWithCurrentlyRunningGroupCalls[call.group.groupIdentity] = existingCallsInGroup
    }
    
    private func groupCalls(in group: GroupCallThreemaGroupModel) -> [GroupCallActor] {
        Array(groupsWithCurrentlyRunningGroupCalls[group.groupIdentity] ?? [])
    }
    
    private func createCall(
        in group: GroupCallThreemaGroupModel,
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
    
    /// Peeks the given call without running any of the refresh steps, since those may remove the call and delete its
    /// database entity.
    /// - Returns: `false` only if the SFU told us that the call is no longer running
    private func mightStillBeRunning(_ groupCall: GroupCallActor) async -> Bool {
        do {
            return try await groupCall.stillRunning() != .ended
        }
        catch {
            DDLogWarn(
                "[GroupCall] Could not peek call \(groupCall.callID): \(error). Assume that it is still running"
            )
            return true
        }
    }

    private func showIncomingGroupCallNotification(
        groupModel: GroupCallThreemaGroupModel,
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
    public func getCallID(in groupModel: GroupCallThreemaGroupModel) -> String? {
        groupsWithCurrentlyRunningGroupCalls[groupModel.groupIdentity]?.first?.callID.bytes.hexEncodedString()
    }
}

extension GroupCallManager {

    /// Cancel the periodic refresh task.
    /// Call this when the app enters background to prevent stale in-flight peek requests
    /// from causing incorrect call removal after iOS suspends and resumes the app.
    public func cancelPeriodicRefresh() {
        periodicCallCheckTask?.cancel()
        periodicCallCheckTask = nil
        DDLogNotice("[GroupCall] [PeriodicCleanup] Cancelled periodic refresh (app entering background)")
    }

    public func startPeriodicCheckIfNeeded() {
        guard periodicCallCheckTask == nil else {
            return
        }
        periodicCallCheckTask = Task { [weak self] in
            while let self {
                do {
                    try await runPeriodicRefresh()
                    try await Task.sleep(seconds: 10)
                }
                catch is CancellationError {
                    DDLogNotice("[GroupCall] [PeriodicCleanup] Periodic refresh task cancelled")
                    return
                }
                catch {
                    DDLogError("[GroupCall] [PeriodicCleanup] Cleanup failed. Removing periodicCallCheckTask. \(error)")
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
        
        DDLogNotice("[GroupCall] [PeriodicCleanup] Refresh started")
        isPeriodicRefreshRunning = true
        
        await withThrowingTaskGroup(of: Void.self) { group in
            for groupIdentity in groupsWithCurrentlyRunningGroupCalls.keys {
                group.addTask {
                    try await self.refreshRunningGroupCalls(in: groupIdentity)
                }
            }
        }
        
        isPeriodicRefreshRunning = false
        DDLogNotice("[GroupCall] [PeriodicCleanup] Refresh ended")
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
            "[GroupCall] [PeriodicCleanup] Refreshing calls in group (\(group)): \(currentCalls.count) currently running calls"
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
            DDLogNotice("[GroupCall] [PeriodicCleanup] There are no more calls running in group (\(group))")
            return
        }
        
        // The full task will be tried to rerun by `GroupCallManager` after 10s or wait for the current running task
        // if it hasn't completed
        //
        // Note: The protocol removes calls with an unknown or failed peek result from `calls` for this round, which
        // would hide the banner until the next successful peek. We deliberately keep them eligible and keep showing
        // their last known state instead, so that a short connectivity loss does not make the banner flicker. Calls
        // with an unsupported protocol version are excluded in `getCurrentlyChosenCall(from:)`.
        if let actor = try await getCurrentlyChosenCall(from: currentCalls) {
            let buttonAndBannerUpdate = await GroupCallBannerButtonUpdate(actor: actor, hideComponent: false)
            
            singletonDelegate?
                .updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: buttonAndBannerUpdate)
        }
        
        DDLogNotice(
            "[GroupCall] [PeriodicCleanup] Refresh completed for calls running in group (\(group)): There are still \(currentCalls.count) calls running"
        )
    }
    
    private func peekCall(_ groupCall: GroupCallActor) async {
        // Check if we have been cancelled
        guard !Task.isCancelled else {
            return
        }

        DDLogNotice("[GroupCall] [PeriodicCleanup] Peeking call \(groupCall.callID)")
        do {
            /// **Protocol Step: Periodic Refresh (3.1. - 3.4.)**
            switch try await periodicRefresh(for: groupCall) {
            case .keep:
                /// **Protocol Step: Periodic Refresh** 3.5 Reset the call's failed counter to 0.
                await groupCall.resetFailedCounter()

                /// **Protocol Step: Periodic Refresh** 3.6. If the protocol version of the call is not supported,
                /// remove call from calls (but keep it in running), log a warning that a group call with an
                /// unsupported version is currently running and abort the peek-call sub-steps.
                warnIfUnsupportedProtocolVersion(groupCall)
                return

            case .skip:
                return

            case .remove:
                await removeAndPostCallEnded(groupCall)
                return

            // TODO: (IOS-4070) This should probably not exist, we should retry in periodic refresh directly, for legibility.
            case .retry:
                /// **Protocol Step: Periodic Refresh** 3.3.1. Refresh the SFU Token. If the SFU Token refresh
                /// fails or does not yield an SFU Token within 10s, remove call from calls (but keep it in
                /// running) and abort the peek-call sub-steps.
                let task = Task {
                    try await dependencies.httpHelper.sfuCredentials()
                }

                switch try await Task.timeout(task, 10) {
                case let .error(error):
                    DDLogWarn(
                        "[GroupCall] [PeriodicCleanup] Token refresh for call with id \(groupCall.callID) failed: \(String(describing: error)). Keeping call"
                    )
                    if await failedPeekResult(for: groupCall) == .remove {
                        await removeAndPostCallEnded(groupCall)
                    }

                case .timeout:
                    DDLogWarn(
                        "[GroupCall] [PeriodicCleanup] Token refresh for call with id \(groupCall.callID) timed out. Keeping call"
                    )
                    if await failedPeekResult(for: groupCall) == .remove {
                        await removeAndPostCallEnded(groupCall)
                    }

                case .result:
                    /// **Protocol Step: Periodic Refresh** 3.3.3. Restart the peek-call sub-steps for this
                    /// call.
                    switch try await periodicRefresh(for: groupCall) {
                    case .keep:
                        await groupCall.resetFailedCounter()
                        warnIfUnsupportedProtocolVersion(groupCall)

                    case .remove:
                        await removeAndPostCallEnded(groupCall)

                    case .retry, .skip:
                        // We do not retry more than once per round. The call is kept and peeked again in the
                        // next round.
                        return
                    }
                }
            }
        }
        catch {
            // The peek might be cancelled due to a new one starting, but we do not want to remove the call in this
            // case.
            guard !(error is CancellationError) else {
                return
            }

            // Any other error is treated like a failed peek: the call is kept and handled by the failed-counter
            // path, since the call might still be running (e.g. the SFU was temporarily unreachable).
            DDLogWarn(
                "[GroupCall] [PeriodicCleanup] An error occurred when peeking call with id \(groupCall.callID): \(error). Keeping call"
            )
            if await failedPeekResult(for: groupCall) == .remove {
                await removeAndPostCallEnded(groupCall)
            }
            return
        }
    }

    private func removeAndPostCallEnded(_ groupCall: GroupCallActor) async {
        await remove(groupCall)

        do {
            let group = groupCall.group
            try await dependencies.groupCallSystemMessageAdapter.post(.groupCallEnded, in: group)
        }
        catch {
            if let error = error as? GroupCallSystemMessageAdapterError {
                DDLogError(
                    "[GroupCall] An error occurred when attempting to post a system message: \(error)"
                )
            }
        }
    }

    /// **Protocol Step: Periodic Refresh** 3.4.3 & 3.4.4: The call is removed only if its failed counter is >= 3
    /// **and** it was received more than 10h ago. Otherwise the failed counter is incremented and the call is kept.
    private nonisolated func failedPeekResult(for groupCallActor: GroupCallActor) async -> PeriodicRefreshResult {
        let failedCounter = await groupCallActor.failedCounter
        if failedCounter >= 3, groupCallActor.receivedMoreThan10HoursAgo {
            return .remove
        }

        await groupCallActor.incrementFailedCounter()
        return .skip
    }

    private nonisolated func warnIfUnsupportedProtocolVersion(_ groupCall: GroupCallActor) {
        if groupCall.protocolVersion > ProtocolDefines.protocolVersion {
            DDLogWarn(
                "[GroupCall] Protocol version of currently running group call (\(groupCall.protocolVersion)) is not the same as supported version (\(ProtocolDefines.protocolVersion)). Keeping call"
            )
        }
    }
    
    private func remove(_ call: GroupCallActor) async {
        await call.leaveCall()
        await call.teardown()
        removeGroupCall(call)
        
        try? await refreshRunningGroupCalls(in: call.group.groupIdentity)
        
        guard let databaseDelegate else {
            DDLogError("[GroupCall] [Peek Steps] We do not have a database delegate set")
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
            /// **Protocol Step: Group Call Peek Steps** 4.: No answer within the peek timeout means the status is
            /// unknown. The call is kept in running and skipped for this round.
            return .skip

        case .invalid:
            /// **Protocol Step: Periodic Refresh** 3.4: If the server could not be reached or the received status code
            /// is not 200 or if the Peek response could not be decoded, the peek failed:

            /// **Protocol Step: Periodic Refresh** 3.4.3 & 3.4.4: Remove only if the failed counter is >= 3 and the
            /// call was received more than 10h ago; otherwise increment the failed counter and keep the call.
            return await failedPeekResult(for: groupCallActor)

        case .invalidToken:
            /// **Protocol Step: Periodic Refresh** 3.3 If the received status code for call is 401 and call is not
            /// marked with token-refreshed:
            guard await !(groupCallActor.tokenRefreshed) else {
                // The token was already refreshed for this call, but we still get a 401. The call might still be
                // running, so it is handled by the failed-counter path instead of being removed.
                return await failedPeekResult(for: groupCallActor)
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
    func getCurrentlyChosenCall(
        from currentCalls: Set<GroupCallActor>?
    ) async throws -> GroupCallActor? {
        var currentlyChosenCall: GroupCallActor?

        guard let currentCalls else {
            return nil
        }

        /// **Protocol Step: Periodic Refresh** 3.6: A call with an unsupported protocol version stays in `running`, but
        /// it was removed from `calls` and thus must never become the chosen call.
        let thisGroupGroupCalls = currentCalls.filter { groupCall in
            guard groupCall.protocolVersion > ProtocolDefines.protocolVersion else {
                return true
            }

            DDLogWarn(
                "[GroupCall] Do not choose call \(groupCall.callID) because its protocol version (\(groupCall.protocolVersion)) is not supported"
            )
            return false
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
                "[GroupCall] [Periodic Refresh] [Peek Steps] Previously chosen call \(innerChosenCall.callID) has creation timestamp \(currentCreationTimestamp)"
            )
            DDLogNotice(
                "[GroupCall] [Periodic Refresh] [Peek Steps] Potential new chosen call \(groupCall.callID) has creation timestamp \(newStartCreationTimestamp)"
            )
            
            if currentCreationTimestamp < newStartCreationTimestamp {
                currentlyChosenCall = groupCall
                
                DDLogNotice(
                    "[GroupCall] [Periodic Refresh] [Peek Steps] Choose call \(innerChosenCall.callID) with creation timestamp \(newStartCreationTimestamp)"
                )
            }
            else {
                DDLogNotice(
                    "[GroupCall] [Periodic Refresh] [Peek Steps] Choose call \(innerChosenCall.callID) with creation timestamp \(currentCreationTimestamp)"
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
            "[GroupCall] [Peek Steps] Chosen Call \(currentlyChosenCall.callID)"
        )
        for groupCall in thisGroupGroupCalls.filter({ $0 != currentlyChosenCall }) {
            if await groupCall.isChosenCall {
                let msg =
                    "[GroupCall] We may only have one chosen call for each group. But despite resetting it just above we still have multiple."
                assertionFailure(msg)
                DDLogError("\(msg)")
                return nil
            }
            
            switch await groupCall.joinState() {
            case .joining:
                wasJoiningCall = true
                // We are switching calls, not leaving. Handing the call we are in over to `currentlyChosenCall` before
                // leaving the old one keeps the group call UI alive, it is reused for the call we join below.
                currentlyJoiningOrJoinedCall = currentlyChosenCall
                await groupCall.forceLeaveCall()
                await remove(groupCall)
                DDLogNotice("[GroupCall] [Peek Steps] Stopping running call \(groupCall.callID)")

            case .joined:
                wasParticipatingInCall = true
                currentlyJoiningOrJoinedCall = currentlyChosenCall
                await groupCall.forceLeaveCall()
                await remove(groupCall)
                DDLogNotice("[GroupCall] [Peek Steps] Stopping joined call \(groupCall.callID)")

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
            DDLogNotice("[GroupCall] [Peek Steps] Joining call \(currentlyChosenCall.callID)")
            try await joinAndShow(currentlyChosenCall)
        }
        /// **Protocol Step: Periodic Refresh (9.)**
        /// 9. If the user is currently participating in a group call of this group that is different to `chosen-call`,
        /// exit the running group call and run the _Group Call Join Steps_ asynchronously with the `intent` to _only
        /// join_ `chosen-call`.
        else if wasParticipatingInCall {
            DDLogNotice("[GroupCall] [Peek Steps] Joining call \(currentlyChosenCall.callID)")
            assert(!wasJoiningCall)
            try await joinAndShow(currentlyChosenCall)
        }
        
        /// **Protocol Step: Periodic Refresh (10.)**
        /// 10. Return `chosen-call`.
        return currentlyChosenCall
    }

    /// Joins the call we switched to and shows its UI
    ///
    /// Only use this when switching to another call of the same group, i.e. when `currentlyJoiningOrJoinedCall` was
    /// already handed over to `groupCall` before leaving the call we were in.
    private func joinAndShow(_ groupCall: GroupCallActor) async throws {
        do {
            try await groupCall.join(intent: .join)
        }
        catch {
            currentlyJoiningOrJoinedCall = nil
            throw error
        }

        currentlyJoiningOrJoinedCall = groupCall

        let viewController = await GroupCallViewController(
            viewModel: groupCall.viewModel,
            dependencies: dependencies
        )
        singletonDelegate?.showGroupCallViewController(viewController: viewController)
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
        // This is also called for calls the local user never participated in, and twice for the same call (when leaving
        // and when tearing it down). Only the transition away from the call we are in is of interest.
        guard groupCall == currentlyJoiningOrJoinedCall else {
            return
        }

        currentlyJoiningOrJoinedCall = nil

        // Note that the call itself might still be running with other participants
        singletonDelegate?.localUserLeftGroupCall(in: groupCall.group.groupIdentity)
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
        
        let localParticipant = try! await LocalParticipant(
            participantID: ParticipantID(id: 0),
            localContactModel: localContactModel,
            dependencies: dependencies
        )
        
        var participantsList: [ViewModelParticipant] = [localParticipant]
        
        for (index, participantThreemaIdentity) in participantThreemaIdentities.enumerated() {
     
            let participant = await ScreenshotParticipant(
                participantID: ParticipantID(id: UInt32(index + 1)),
                threemaIdentity: participantThreemaIdentity,
                dependencies: dependencies,
                audioMuteState: .muted,
                videoMuteState: .muted
            )
            participantsList.append(participant)
        }
        
        let viewModel = GroupCallViewModel(
            screenshotGroupName: groupName,
            localParticipant: localParticipant,
            participantsList: participantsList,
            dependencies: dependencies
        )
        
        return await GroupCallViewController(
            viewModel: viewModel,
            dependencies: dependencies,
            isRunningForScreenShots: true
        )
    }
}
