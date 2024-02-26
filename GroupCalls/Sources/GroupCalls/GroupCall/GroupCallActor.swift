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
import CryptoKit
import Foundation
import ThreemaEssentials
import ThreemaProtocols
@preconcurrency import WebRTC

// Manages a single group call
actor GroupCallActor: Sendable {
    
    // MARK: - Internal Properties

    let sfuHTTPConnection: SFUHTTPConnection
    
    let dependencies: Dependencies
    
    let proposedGroupCall: ProposedGroupCall
    
    let groupCallBaseState: GroupCallBaseState
    
    // TODO: (IOS-4427)
    nonisolated var groupCallBaseStateCopy: GroupCallBaseState {
        try! GroupCallBaseState(
            group: group,
            startedAt: groupCallBaseState.startedAt,
            dependencies: dependencies,
            groupCallStartData: groupCallStartData
        )
    }
    
    // MARK: Protocol Peek Steps Helper Variables

    var tokenRefreshed = false
    var failedCounter = 0
    let startMessageReceiveDate: Date
    var isChosenCall = false
    var isNew = false
    
    // MARK: Non-isolated Properties
    
    nonisolated var group: GroupCallsThreemaGroupModel {
        groupCallBaseState.group
    }
    
    nonisolated var callID: GroupCallID {
        groupCallBaseState.callID
    }
    
    nonisolated var protocolVersion: UInt32 {
        groupCallBaseState.protocolVersion
    }
    
    nonisolated var sfuBaseURL: String {
        groupCallBaseState.sfuBaseURL
    }
    
    nonisolated var logIdentifier: String {
        "\(groupCallBaseState.callID.bytes.base64EncodedString().prefix(6))"
    }
    
    nonisolated var receivedMoreThan10HoursAgo: Bool {
        startMessageReceiveDate.timeIntervalSinceNow < -(60 * 60 * 10)
    }
    
    // MARK: View Model

    lazy var viewModel = GroupCallViewModel(groupCallActor: self) {
        didSet {
            let msg = "[GroupCall] viewModel may not change after it was initially set"
            DDLogError(msg)
            assertionFailure(msg)
        }
    }
    
    /// The exact call start date of the call as determined by the SFU
    ///
    /// Use this for ordering calls by call creation time.
    var exactCallStartDate: UInt64?

    let localContactModel: ContactModel
    var localParticipant: LocalParticipant? = nil
    
    // MARK: Streams
    
    let uiActionQueue: AsyncStream<GroupCallUIAction>
    private let uiActionContinuation: AsyncStream<GroupCallUIAction>.Continuation
    
    let uiQueue: AsyncStream<GroupCallUIEvent>
    let uiContinuation: AsyncStream<GroupCallUIEvent>.Continuation
    
    private var callLeaveQueue: AsyncStream<Void>?
    var callLeaveContinuation: AsyncStream<Void>.Continuation?
        
    private weak var actorDelegate: GroupCallActorManagerDelegate?
    
    // MARK: - Private Properties
    
    /// `True` between the point where join call was called and the state changed to joining
    /// `False` otherwise
    private var startJoining = false
    
    private var startMessage: CspE2e_GroupCallStart?
    
    private var numberOfParticipants = 0
    
    private lazy var state: GroupCallState = UnJoined(groupCallActor: self) {
        didSet {
            switch state.self {
            case is UnJoined:
                return
            case is Joining:
                startJoining = false
                uiContinuation.yield(.joining)
                Task {
                    await updateButtonAndBanner()
                }
            case is Connecting:
                uiContinuation.yield(.connecting)
                Task {
                    await updateButtonAndBanner()
                }
            case is Connected:
                uiContinuation.yield(.connected)
                Task {
                    await updateButtonAndBanner()
                }
            default:
                DDLogWarn(
                    "[GroupCall] State changed but no notice given to the view model for state \(state.self)"
                )
            }
        }
    }
    
    private let groupCallStartData: GroupCallStartData
    
    /// Task running group call state machine
    private var currentTask: Task<Void, Error>?
    private var sendCallStartMessageDelayTask: Task<Void, Error>?

    private(set) var currentCameraPosition: CameraPosition = .front
    
    // MARK: - Lifecycle
    
    init(
        localContactModel: ContactModel,
        groupModel: GroupCallsThreemaGroupModel,
        sfuBaseURL: String,
        gck: Data,
        protocolVersion: UInt32 = 1,
        startMessageReceiveDate: Date = Date(),
        actorDelegate: GroupCallActorManagerDelegate? = nil,
        dependencies: Dependencies
    ) throws {
        self.groupCallStartData = GroupCallStartData(
            protocolVersion: protocolVersion,
            gck: gck,
            sfuBaseURL: sfuBaseURL
        )
        
        self.groupCallBaseState = try GroupCallBaseState(
            group: groupModel,
            startedAt: Date(),
            dependencies: dependencies,
            groupCallStartData: groupCallStartData
        )
        self.actorDelegate = actorDelegate
        self.dependencies = dependencies
        self.localContactModel = localContactModel
        
        self.sfuHTTPConnection = SFUHTTPConnection(
            dependencies: dependencies,
            groupCallDescription: groupCallBaseState
        )
        
        self.proposedGroupCall = ProposedGroupCall(
            groupRepresentation: groupModel,
            protocolVersion: protocolVersion,
            gck: gck,
            sfuBaseURL: sfuBaseURL,
            startMessageReceiveDate: startMessageReceiveDate,
            dependencies: dependencies
        )
        
        self.startMessageReceiveDate = startMessageReceiveDate
        
        (self.uiActionQueue, self.uiActionContinuation) = AsyncStream<GroupCallUIAction>.makeStream()
        (self.uiQueue, self.uiContinuation) = AsyncStream<GroupCallUIEvent>.makeStream()
        observeNotifications()
    }
    
    deinit {
        uiActionContinuation.finish()
        uiContinuation.finish()
    }
    
    nonisolated func observeNotifications() {
        Task {
            let resignNotifications = await NotificationCenter.default.notifications(
                named: UIApplication.willResignActiveNotification,
                object: nil
            )
            for await _ in resignNotifications {
                await toggleOwnVideo(true)
            }
        }
    }
    
    // MARK: - State Functions
    
    func process(state: GroupCallState) async {
        defer {
            dependencies.groupCallSessionHelper.setHasActiveGroupCall(to: false, groupName: nil)
        }
        dependencies.groupCallSessionHelper.setHasActiveGroupCall(to: true, groupName: group.groupName)
        
        var iterator: GroupCallState? = state
        
        while let current = iterator {
            // TODO: (IOS-3857) Logging
            DDLogNotice("[GroupCall] State is \(current.self)")
            self.state = current
            
            guard !(state is Ended) else {
                break
            }
            
            do {
                iterator = try await current.next()
            }
            catch let error as GroupCallError where !error.isFatal {
                let message = "[GroupCall] Caught non-fatal GroupCallError: \(error)"
                DDLogError(message)
                assertionFailure(message)
                continue
            }
            catch {
                let message = "[GroupCall] Caught error: \(error). Tearing down."
                DDLogError(message)
                assertionFailure(message)
                iterator = await Ending(groupCallActor: self)
            }
        }
        
        /// **Leave Call** 4. All other things are cleaned up now, we finish with the actor itself.
        await leaveCall(runRefreshSteps: true)
    }
    
    enum PeekResult {
        case running
        case ended
        case timeout
        case invalidToken
        case invalid
    }
    
    func setTokenRefreshed() {
        tokenRefreshed = true
    }
    
    func incrementFailedCounter() {
        failedCounter += 1
    }
    
    func resetFailedCounter() {
        failedCounter = 0
    }
    
    func stillRunning() async throws -> PeekResult {
        /// **Protocol Step: Periodic Refresh** 3.1. If the user is currently participating in call, abort the peek-call
        /// sub-steps.
        guard state is UnJoined else {
            return .running
        }
        
        /// **Protocol Step: Periodic Refresh** 3.2. Peek the call via a SfuHttpRequest.Peek request. If this does not
        /// result in a response within 5s, remove call from calls and abort the peek-call sub-steps.
        let task = Task {
            try await self.sfuHTTPConnection.peek()
        }
        
        let intermediateResult = try await Task.timeout(task, 5)
        
        switch intermediateResult {
        case let .error(error):
            if let error {
                if case GroupCallError.invalidToken = error {
                    return .invalidToken
                }
                throw error
            }
            else {
                return .invalid
            }
            
        case .timeout:
            return .timeout
            
        case let .result(peekResponse):
            return try await handle(peekResult: peekResponse)
        }
    }
    
    func handle(peekResult: SFUHTTPConnection.PeekResponse) async throws -> PeekResult {
        switch peekResult {
        case let .running(peekResponse):
            exactCallStartDate = peekResponse.startedAt
            groupCallBaseState.maxParticipants = Int(peekResponse.maxParticipants)

            if peekResponse.hasEncryptedCallState {
                let nonce = peekResponse.encryptedCallState[0..<24]
                let peekResponseData = peekResponse.encryptedCallState[24..<peekResponse.encryptedCallState.count]
                
                guard let decryptedData = groupCallBaseState.symmetricDecryptByGSCK(peekResponseData, nonce: nonce),
                      let decryptedCallState = try? Groupcall_CallState(serializedData: decryptedData) else {
                    DDLogError("[GroupCall] Peek Could not decrypt encrypted call state")
                    throw GroupCallError.decryptionFailure
                }
                                
                // We add one for the creator, which is not included in participants
                numberOfParticipants = decryptedCallState.participants.count + 1
                
                await updateButtonAndBanner()
                
                DDLogNotice(
                    "[GroupCall] [PeriodicCleanup] Still running call with id \(logIdentifier)"
                )
            }
            return .running
            
        case .notDetermined:
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] Not determined call with id \(logIdentifier)"
            )
            return .invalid
            
        case .invalidRequest:
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] Invalid Request for call with id \(logIdentifier)"
            )
            await updateButtonAndBanner(hide: true)
            return .ended
            
        case .needsTokenRefresh:
            return .invalidToken
            
        case .notRunning:
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] Not running call with id \(logIdentifier)"
            )
            await updateButtonAndBanner(hide: true)
            return .ended
        }
    }
    
    func connectedConfirmed() {
        uiActionContinuation.yield(.connectedConfirmed)
    }
    
    func joinState() -> GroupCallJoinState {
        if state is Connected {
            return .runningLocal
        }
        
        if startJoining, state is Connecting || state is Joining {
            return .joining
        }
        return .notRunningLocal
    }
    
    func setIsChosenCall() -> Bool {
        defer {
            self.isChosenCall = true
        }
        
        if isChosenCall == false {
            return true
        }
        else {
            return false
        }
    }
    
    func removeIsChosenCall() -> Bool {
        defer {
            self.isChosenCall = false
        }
        if isChosenCall == true {
            return true
        }
        else {
            return false
        }
    }
    
    func setExactCallStartDate(_ exactCallStartDate: UInt64) {
        self.exactCallStartDate = exactCallStartDate
    }
    
    private func updateButtonAndBanner(hide: Bool = false) async {
        let buttonBannerUpdate = await GroupCallBannerButtonUpdate(actor: self, hideComponent: hide)
        await actorDelegate?.updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: buttonBannerUpdate)
    }
}

// MARK: -  Group Call Join Steps & Create Steps

extension GroupCallActor {
    public func join(intent: GroupCallUserIntent) async throws {
        startJoining = true

        /// **Protocol Step: Group Call Join Steps**
        /// 1. Let intent be either only join or create or join. Let call be the given group call to be joined (or
        /// created).
        /// Note: `call` is here the class itself.
        
        // We start the process loop.
        currentTask = Task.detached(priority: .userInitiated, operation: { [weak self] in
            
            guard let self else {
                return
            }
            await self.process(state: self.state)
        })
        
        DDLogNotice("[GroupCall] Call is not yet connected but is \(state). Wait…")
    }
    
    // Create or Join step 5
    public func createStartMessage(token: SFUToken, gck: Data) {
        startMessage = CspE2e_GroupCallStart.with {
            $0.protocolVersion = GroupCallConfiguration.ProtocolDefines.protocolVersion
            $0.gck = gck
            $0.sfuBaseURL = token.sfuBaseURL
        }
        isNew = true
    }
    
    public func sendStartMessageWithDelay() async throws -> Bool {
        guard let startMessage else {
            throw GroupCallError.creationError
        }
        
        /// **Protocol Step: Group Call Join Steps**
        /// 7.1 Optionally add an artificial wait period of 2s minus the time elapsed since step 1. Since we do not have
        /// the elapsed time, we estimate it to 1.5s.
        sendCallStartMessageDelayTask = Task {
            try? await Task.sleep(seconds: 1.5)
        }
        try? await sendCallStartMessageDelayTask?.value
        
        // We stop sending the start message if call was ended during the delay. To correctly teardown everything, we
        // first add id to running group calls.
        if let sendCallStartMessageDelayTask, sendCallStartMessageDelayTask.isCancelled {
            self.sendCallStartMessageDelayTask = nil
            await actorDelegate?.addToRunningGroupCalls(groupCall: self)
            return false
        }
        
        sendCallStartMessageDelayTask = nil
        
        /// 7.2 Announce (the previously created but not yet sent) call in the associated group by sending it as a
        /// GroupCallStart message.
        let wrappedMessage = WrappedGroupCallStartMessage(
            startMessage: startMessage,
            groupIdentity: group.groupIdentity
        )
        try await actorDelegate?.sendStartCallMessage(wrappedMessage)
        try await dependencies.groupCallSystemMessageAdapter.post(.groupCallStarted, in: group)
        
        isNew = false
        return true
    }
}

// MARK: - GroupCallActorManagerDelegate helpers

extension GroupCallActor {
    
    public func addSelfToCurrentlyRunningCalls() async {
        await actorDelegate?.addToRunningGroupCalls(groupCall: self)
    }
    
    public func startRefreshSteps() async {
        await actorDelegate?.startRefreshSteps()
    }
}

// MARK: View Model

extension GroupCallActor {
    
    func getNumberOfParticipants() -> Int {
        numberOfParticipants
    }
        
    func add(_ localParticipant: LocalParticipant) async {
        self.localParticipant = localParticipant
        
        let (avatar, idColor) = dependencies.groupCallParticipantInfoFetcher.fetchInfoForLocalIdentity()

        let viewModelParticipant = await ViewModelParticipant(
            localParticipant: localParticipant,
            name: dependencies.groupCallBundleUtil.localizedString(for: "me"),
            avatar: avatar,
            idColor: idColor
        )
        uiContinuation.yield(.addLocalParticipant(viewModelParticipant))
        await updateButtonAndBanner()
    }
    
    func add(_ remoteParticipant: RemoteParticipant) async {
        
        guard let id = await remoteParticipant.threemaIdentity?.string else {
            return
        }
        let (displayName, avatar, idColor) = dependencies.groupCallParticipantInfoFetcher.fetchInfo(id: id)
        let viewModelParticipant = await ViewModelParticipant(
            remoteParticipant: remoteParticipant,
            name: displayName,
            avatar: avatar,
            idColor: idColor
        )
        uiContinuation.yield(.add(viewModelParticipant))
        await updateButtonAndBanner()
    }
    
    func remove(_ remoteParticipant: RemoteParticipant) async {
        await uiContinuation.yield(.remove(remoteParticipant.getID()))
        await updateButtonAndBanner()
    }
    
    func subscribeVideo(for participantID: ParticipantID) {
        uiActionContinuation.yield(.subscribeVideo(participantID))
    }
    
    func unsubscribeVideo(for participantID: ParticipantID) {
        uiActionContinuation.yield(.unsubscribeVideo(participantID))
    }
    
    func toggleOwnAudio(_ mute: Bool) {
        uiActionContinuation.yield(mute ? .muteAudio : .unmuteAudio)
    }
    
    func toggleOwnVideo(_ mute: Bool) {
        uiActionContinuation.yield(mute ? .muteVideo : .unmuteVideo(currentCameraPosition))
    }
    
    func assertNotConnected() {
        assert(state.self is Ended || state.self is UnJoined)
        assert(currentTask == nil)
    }
    
    func beginLeaveCall() {
        /// **Leave Call** 2. To terminate the process loop, we yield `.leave`
        guard currentTask != nil else {
            Task {
                await viewModel.leaveCall()
            }
            return
        }
        // We cancel the start message delay task if we were connecting
        sendCallStartMessageDelayTask?.cancel()
        
        uiActionContinuation.yield(.leave)
    }
    
    func leaveCall(runRefreshSteps: Bool = false) async {
        DDLogVerbose("[GroupCall] Teardown: Actor")
        state = UnJoined(groupCallActor: self)

        await updateButtonAndBanner()
        await actorDelegate?.removeFromRunningGroupCalls(groupCall: self)
        
        callLeaveContinuation?.yield()
        
        if runRefreshSteps {
            await actorDelegate?.refreshGroupCalls(in: group.groupIdentity)
        }
    }
    
    func forceLeaveCall() async {
        if callLeaveQueue == nil {
            (callLeaveQueue, callLeaveContinuation) = AsyncStream.makeStream()
        }
        
        let leaveTask: Task<Void, Error> = Task {
            // We directly dismiss the call view without an animation, other wise the presentation of the new call
            // fails.
            uiContinuation.yield(.forceDismissGroupCallViewController)
            
            // This creates a suspension point, we must wait with continuing the force leave until the basic clean up
            // has finished processing
            uiActionContinuation.yield(.leave)
            
            if let callLeaveQueue {
                for await _ in callLeaveQueue {
                    self.callLeaveContinuation?.finish()
                }
                
                self.callLeaveQueue = nil
                self.callLeaveContinuation = nil
            }
        }
        
        do {
            switch try await Task.timeout(leaveTask, 5) {
            case .result:
                break
            case .error:
                let msg = "An error occurred while waiting for the leave call confirmation signal."
                assertionFailure(msg)
                DDLogError(msg)
            case .timeout:
                let msg = "Waiting for call leave confirmation timed out."
                assertionFailure(msg)
                DDLogWarn(msg)
            }
        }
        catch {
            let msg = "An error occurred while waiting for the call leave confirmation \(error). Terminating anyway."
            assertionFailure(msg)
            DDLogError(msg)
        }
    }
    
    func showGroupCallFullAlert(maxParticipants: Int?) async {
        await actorDelegate?.showGroupCallFullAlert(maxParticipants: maxParticipants)
        await updateButtonAndBanner(hide: true)
    }

    func teardown() async {
        DDLogVerbose("[GroupCall] Leave: Actor")
        
        state = UnJoined(groupCallActor: self)
        await viewModel.teardown()
        
        uiContinuation.finish()
        uiActionContinuation.finish()
        
        currentTask?.cancel()
        currentTask = nil
        
        await updateButtonAndBanner(hide: true)
        await actorDelegate?.removeFromRunningGroupCalls(groupCall: self)
    }
    
    func switchCamera() {
        if currentCameraPosition == .front {
            currentCameraPosition = .back
        }
        else {
            currentCameraPosition = .front
        }
        uiActionContinuation.yield(.switchCamera(currentCameraPosition))
    }

    func remoteContext(for participantID: ParticipantID) async -> RemoteContext? {
        await (state as? Connected)?.getRemoteContext(for: participantID)
    }
    
    func localContext() async -> RTCVideoTrack? {
        
        if state is Connected {
            return await (state as? Connected)?.localVideoTrack()
        }
        else if state is Connecting {
            return await (state as? Connecting)?.localVideoTrack()
        }
        return nil
    }
}

// MARK: - Equatable

extension GroupCallActor: Equatable {
    static func == (lhs: GroupCallActor, rhs: GroupCallActor) -> Bool {
        lhs.groupCallBaseState.callID == rhs.groupCallBaseState.callID
    }
}

// MARK: - Hashable

extension GroupCallActor: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(groupCallBaseState.callID.bytes)
    }
}
