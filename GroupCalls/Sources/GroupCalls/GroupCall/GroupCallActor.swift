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
import CryptoKit
import Foundation
import ThreemaProtocols
import WebRTC

// Manages a single group call
actor GroupCallActor: Sendable {
    
    // MARK: - Internal Properties

    let sfuHTTPConnection: SFUHTTPConnection
    
    let dependencies: Dependencies
    
    let proposedGroupCall: ProposedGroupCall
    
    // MARK: Protocol Peek Steps Helper Variables

    var tokenRefreshed = false
    var failedCounter = 0
    let startMessageReceiveDate: Date
    var isChosenCall = false
    
    // MARK: Nonisolated Properties
    
    nonisolated var group: GroupCallsThreemaGroupModel {
        groupCallDescription.group
    }
    
    nonisolated var callID: GroupCallID {
        groupCallDescription.callID
    }
    
    nonisolated var protocolVersion: UInt32 {
        groupCallDescription.protocolVersion
    }
    
    nonisolated var sfuBaseURL: String {
        groupCallDescription.sfuBaseURL
    }
    
    nonisolated var groupCallDescriptionCopy: GroupCallBaseState {
        try! GroupCallBaseState(
            group: group,
            startedAt: groupCallDescription.startedAt,
            // TODO: Use actual value
            maxParticipants: groupCallDescription.maxParticipants,
            dependencies: dependencies,
            groupCallStartData: groupCallStartData
        )
    }
    
    nonisolated var logIdentifier: String {
        "\(groupCallDescription.callID.bytes.base64EncodedString().prefix(6))"
    }
    
    nonisolated var receivedMoreThan10HoursAgo: Bool {
        startMessageReceiveDate.timeIntervalSinceNow < 60 * 60 * 10
    }
    
    // MARK: View Model

    lazy var viewModel = GroupCallViewModel(groupCallActor: self) {
        didSet {
            let msg = "[GroupCall] viewModel may not change after it was initially set"
            DDLogError(msg)
            assertionFailure(msg)
        }
    }
    
    var hasEnded: Bool {
        state.self is Ended
    }
    
    /// The approximate call start date
    ///
    /// Do not use this for sorting calls by call creation time.
    var approximateCallStartDateUI: Date?
    
    /// The exact call start date of the call as determined by the SFU
    ///
    /// Use this for ordering calls by call creation time.
    var exactCallStartDate: UInt64?

    let localIdentity: ThreemaID
    
    var localParticipant: LocalParticipant? = nil
    
    // MARK: Streams
    
    let stateQueue: AsyncStream<GroupCallUIAction>
    private let stateContinuation: AsyncStream<GroupCallUIAction>.Continuation
    
    let uiQueue: AsyncStream<GroupCallUIEvent>
    let uiContinuation: AsyncStream<GroupCallUIEvent>.Continuation
    
    private var callStopSignal: AsyncStream<Void>?
    var callStopSignalContinuation: AsyncStream<Void>.Continuation?
    
    // MARK: - Private Properties
    
    /// True between the point where join call was called and the state changed to joining
    /// False otherwise
    private var startJoining = false
    
    private var numberOfParticipants = 0
    
    private lazy var state: GroupCallState = UnJoined(groupCallActor: self) {
        didSet {
            if let callStartStateContinuation {
                callStartStateContinuation.yield(state)
            }
            
            switch state.self {
            case is UnJoined:
                DDLogNotice("")
            case is Joining:
                startJoining = false
                uiContinuation.yield(.joining)
            case is Connecting:
                uiContinuation.yield(.connecting)
            case is Connected:
                uiContinuation.yield(.connected)
            default:
                DDLogWarn(
                    "[GroupCall] State changed but no notice given to the view model for state \(state.self)"
                )
            }
        }
    }
    
    private let groupCallDescription: GroupCallBaseState
    private let groupCallStartData: GroupCallStartData
    
    private var currentTask: Task<Void, Error>?
    private var currentCameraPosition: CameraPosition = .front
    
    private var callStartStateQueue: AsyncStream<GroupCallState>?
    private var callStartStateContinuation: AsyncStream<GroupCallState>.Continuation?
    
    // MARK: - Lifecycle
    
    init(
        localIdentity: ThreemaID,
        groupModel: GroupCallsThreemaGroupModel,
        sfuBaseURL: String,
        gck: Data,
        protocolVersion: UInt32 = 1,
        startMessageReceiveDate: Date = Date(),
        dependencies: Dependencies
    ) throws {
        self.groupCallStartData = GroupCallStartData(
            protocolVersion: protocolVersion,
            gck: gck,
            sfuBaseURL: sfuBaseURL
        )
        
        self.groupCallDescription = try GroupCallBaseState(
            group: groupModel,
            startedAt: Date(),
            // TODO: Use actual value
            maxParticipants: 100,
            dependencies: dependencies,
            groupCallStartData: groupCallStartData
        )
        self.dependencies = dependencies
        self.localIdentity = localIdentity
        
        self.sfuHTTPConnection = SFUHTTPConnection(
            dependencies: dependencies,
            groupCallDescription: groupCallDescription
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
        
        (self.stateQueue, self.stateContinuation) = AsyncStream<GroupCallUIAction>.makeStream()
        (self.uiQueue, self.uiContinuation) = AsyncStream<GroupCallUIEvent>.makeStream()
        observeNotifications()
    }
    
    deinit {
        stateContinuation.finish()
        uiContinuation.finish()
    }
    
    nonisolated func observeNotifications() {
        Task {
            let resignNotifications = await NotificationCenter.default.notifications(
                named: UIApplication.willResignActiveNotification,
                object: nil
            )
            for await _ in resignNotifications {
                try? await toggleOwnVideo(true)
            }
        }
    }
    
    // MARK: - Update Functions
    
    func join(intent: GroupCallUserIntent) async throws {
        /// **Protocol Step: Create or Join** 1. Let `intent` be the user's intent, i.e. to either only join or create
        /// or join a group call.
        startJoining = true
        
        let cancelledOrNil = currentTask?.isCancelled ?? true
        approximateCallStartDateUI = Date.now
        guard cancelledOrNil else {
            DDLogNotice("[GroupCall] We are already runningLocal. Don't try again.")
            assert(!(state is Ended))
            assert(!(state is UnJoined))
            return
        }
        
        if intent == .create {
            (callStartStateQueue, callStartStateContinuation) = AsyncStream<GroupCallState>.makeStream()
        }
        
        currentTask = Task.detached(priority: .userInitiated, operation: { [weak self] in
            guard let self else {
                return
            }
            await self.process(state: self.state)
        })
        
        if intent == .create {
            if !(state is Connected) {
                guard let callStartStateQueue else {
                    fatalError()
                }
                
                for await newState in callStartStateQueue {
                    DDLogNotice("[GroupCall] Waiting for call connected \(newState) ...")
                    if newState is Connected {
                        break
                    }
                    if newState is Ended {
                        break
                    }
                }
            }
            
            callStartStateQueue = nil
            callStartStateContinuation = nil
        }
        
        DDLogNotice("[GroupCall] Call is not yet connected but is \(state). Wait…")
    }
    
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
            catch {
                DDLogError("[GroupCall] An error occurred \(error.localizedDescription)")
                break
            }
        }
        
        uiContinuation.yield(.leaveConfirmed)
        
        self.state = UnJoined(groupCallActor: self)
        
        currentTask?.cancel()
        teardown()
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
        DDLogNotice(
            "[GroupCall] [PeriodicCleanup] Checking call with id \(logIdentifier)"
        )
        
        /// **Protocol Step: Periodic Refresh** 3.1. If the user is currently participating in call, abort the peek-call
        /// sub-steps.
        guard !(state is Connected) else {
            return .running
        }
        
        /// **Protocol Step: Periodic Refresh** 3.2. Peek the call via a SfuHttpRequest.Peek request. If this does not
        /// result in a response within 5s, remove call from calls and abort the peek-call sub-steps.
        let task = Task {
            try await self.sfuHTTPConnection.sendPeek()
        }
        
        let intermediateResult = try await Task.timeout(task, 5)
        
        switch intermediateResult {
        case let .error(error):
            if let error {
                throw error
            }
            else {
                return .invalid
            }
        case .timeout:
            return .timeout
        case let .result(peekResponse):
            if try await handle(peekResult: peekResponse) {
                return .running
            }
            else {
                return .ended
            }
        }
    }
    
    func handle(peekResult: SFUHTTPConnection.PeekResponse) async throws -> Bool {
        switch peekResult {
        case let .running(peekResponse):
            approximateCallStartDateUI = Date(timeIntervalSince1970: TimeInterval(peekResponse.startedAt / 1000))
            exactCallStartDate = peekResponse.startedAt
            
            if peekResponse.hasEncryptedCallState {
                let nonce = peekResponse.encryptedCallState[0..<24]
                let peekResponseData = peekResponse.encryptedCallState[24..<peekResponse.encryptedCallState.count]
                
                guard let decryptedData = groupCallDescription.symmetricDecryptByGSCK(peekResponseData, nonce: nonce),
                      let decryptedCallState = try? Groupcall_CallState(serializedData: decryptedData) else {
                    DDLogError("[GroupCall] Peek Could not decrypt encrypted call state")
                    return false
                }
                
                assert(decryptedCallState.unknownFields.data.isEmpty)
                
                // We add one for the creator, which is not included in participants
                numberOfParticipants = decryptedCallState.participants.count + 1
                let callInfo = GroupCallBannerButtonInfo(
                    numberOfParticipants: numberOfParticipants,
                    startDate: approximateCallStartDateUI ?? .now,
                    joinState: joinState()
                )
                uiContinuation.yield(.stateChanged(.visible(callInfo)))
                
                DDLogNotice(
                    "[GroupCall] [PeriodicCleanup] Still running call with id \(logIdentifier)"
                )
            }
            return true
        case .notDetermined:
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] Not determined call with id \(logIdentifier)"
            )
            return true
        case .timeout:
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] Timeout for call with id \(logIdentifier)"
            )
            
            uiContinuation.yield(.stateChanged(.hidden))
            return false
        case .needsTokenRefresh:
            // TODO: Return this to caller
            fatalError()
        case .notRunning:
            DDLogNotice(
                "[GroupCall] [PeriodicCleanup] Not running call with id \(logIdentifier)"
            )
            
            uiContinuation.yield(.stateChanged(.hidden))
            return false
        }
    }
    
    func connectedConfirmed() {
        stateContinuation.yield(.connectedConfirmed)
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
    
    private func teardown() {
        // TODO: IOS-3728
//        uiContinuation.yield(.stateChanged(.hidden))
//
//        uiContinuation.finish()
//        stateContinuation.finish()
        viewModel.periodicUIUpdateTask?.cancel()
    }
}

extension GroupCallActor {
    // MARK: View Model Access Functions
    
    func getCallStartDate() -> Date? {
        approximateCallStartDateUI
    }
    
    func getNumberOfParticipants() -> Int {
        numberOfParticipants
    }
    
    // MARK: View Model Update Functions
    
    func add(_ localParticipant: LocalParticipant) async {
        self.localParticipant = localParticipant
        
        let (displayName, avatar, idColor) = dependencies.groupCallParticipantInfoFetcher.fetchInfoForLocalIdentity()

        let viewModelParticipant = await ViewModelParticipant(
            localParticipant: localParticipant,
            name: displayName,
            avatar: avatar,
            idColor: idColor
        )
        uiContinuation.yield(.addLocalParticipant(viewModelParticipant))
    }
    
    func add(_ remoteParticipant: RemoteParticipant) async {
        
        guard let id = await remoteParticipant.getIdentity()?.id else {
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
    }
    
    func remove(_ remoteParticipant: RemoteParticipant) async {
        await uiContinuation.yield(.remove(remoteParticipant.getID()))
    }
    
    func reloadViewModel() {
        uiContinuation.yield(.reload)
    }
    
    func subscribeVideo(for participantID: ParticipantID) -> Bool {
        guard state.self is Connected else {
            return false
        }
        stateContinuation.yield(.subscribeVideo(participantID))
        
        return true
    }
    
    func unsubscribeVideo(for participantID: ParticipantID) -> Bool {
        guard state.self is Connected else {
            return false
        }
        stateContinuation.yield(.unsubscribeVideo(participantID))
        
        return true
    }
    
    func toggleOwnAudio(_ mute: Bool) throws {
        stateContinuation.yield(mute ? .muteAudio : .unmuteAudio)
    }
    
    func toggleOwnVideo(_ mute: Bool) throws {
        stateContinuation.yield(mute ? .muteVideo : .unmuteVideo(currentCameraPosition))
    }
    
    func assertNotConnected() {
        assert(state.self is Ended || state.self is UnJoined)
        assert(currentTask == nil)
    }
    
    func stopCall() async -> Bool {
        callStartStateContinuation?.finish()
        
        guard state.self is Connected else {
            currentTask?.cancel()
            return false
        }
        
        if callStopSignal == nil {
            (callStopSignal, callStopSignalContinuation) = AsyncStream.makeStream()
        }
        
        stateContinuation.yield(.leave)
        
        let task: Task<Void, Error> = Task {
            if let callStopSignal {
                for await _ in callStopSignal {
                    self.callStopSignal = nil
                    self.callStopSignalContinuation = nil
                }
            }
        }
        
        do {
            switch try await Task.timeout(task, 10) {
            case .result: break
            case .error:
                let msg = "An error occurred while waiting for the call stop signal"
                assertionFailure(msg)
                DDLogError(msg)
            case .timeout:
                let msg = "Waiting for call stop confirmation timed out"
                assertionFailure(msg)
                DDLogWarn(msg)
            }
        }
        catch {
            let msg = "An error occurred while waiting for the call stop signal \(error)"
            assertionFailure(msg)
            DDLogError(msg)
        }
        
        await viewModel.pop()
        
        currentTask?.cancel()
        stateContinuation.yield(.none)
        
        currentTask = nil
        
        return true
    }
    
    func prepareForRemove() {
        currentTask?.cancel()
        uiContinuation.finish()
        stateContinuation.finish()
    }
    
    func switchCamera() {
        if currentCameraPosition == .front {
            currentCameraPosition = .back
        }
        else {
            currentCameraPosition = .front
        }
        stateContinuation.yield(.switchCamera(currentCameraPosition))
    }
    
    func set(callStartDate: Date) {
        approximateCallStartDateUI = callStartDate
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
    
    func isDominantCompared(to groupCallActor: GroupCallActor) async -> Bool {
        assert(self != groupCallActor)
        
        guard let myStartDate = exactCallStartDate else {
            DDLogNotice(
                "[GroupCall] Checking call \(logIdentifier) against call \(groupCallActor.logIdentifier). The other call is dominant because we do not have a start date even though we checked with the SFU."
            )
            return false
        }
        
        guard let otherStartDate = await groupCallActor.exactCallStartDate else {
            DDLogNotice(
                "[GroupCall] Checking call \(logIdentifier) against call \(groupCallActor.logIdentifier). We are dominant because the other calls does not have a start date even though we checked with the SFU."
            )
            return true
        }
        
        DDLogNotice(
            "[GroupCall] Checking call \(logIdentifier) with start date \(myStartDate) against call \(groupCallActor.logIdentifier) with start date \(otherStartDate)"
        )
        
        // TODO: IOS-3728 What does Android do here or what does the protocol say about this?
        return myStartDate < otherStartDate
    }
}

extension GroupCallActor {
    nonisolated func getExactCallStartDate() async -> UInt64? {
        await exactCallStartDate
    }
}

// MARK: - Equatable

extension GroupCallActor: Equatable {
    static func == (lhs: GroupCallActor, rhs: GroupCallActor) -> Bool {
        lhs.groupCallDescription.callID == rhs.groupCallDescription.callID
    }
}

// MARK: - Hashable

extension GroupCallActor: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(groupCallDescription.callID.bytes)
    }
}
