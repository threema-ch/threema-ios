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
import Foundation
import UIKit
import WebRTC

public final class GroupCallViewModel: Sendable {
    
    typealias DataSource = GroupCallCollectionViewDataSource
    typealias Snapshot = NSDiffableDataSourceSnapshot<DataSource.Section, ParticipantID>
    
    // MARK: - Public Properties

    weak var groupCallActor: GroupCallActor?
    
    @Published var snapshotPublisher = Snapshot()

    public let buttonBannerObserver = AsyncStreamContinuationToSharedPublisher<GroupCallButtonBannerState>()

    var ownAudioMuteState: OwnMuteState = GroupCallConfiguration.LocalInitialMuteState.audio {
        didSet {
            toolBarDelegate?.updateToggleAudioButton()

            guard !isLeavingCall else {
                return
            }
            
            switch ownAudioMuteState {
            case .changing:
                break
            case .muted:
                groupCallActor?.dependencies.notificationPresenterWrapper
                    .presentGroupCallNotification(type: .audioMuted)
            case .unmuted:
                groupCallActor?.dependencies.notificationPresenterWrapper
                    .presentGroupCallNotification(type: .audioUnmuted)
            }
        }
    }
    
    var ownVideoMuteState: OwnMuteState = GroupCallConfiguration.LocalInitialMuteState.video {
        didSet {
            toolBarDelegate?.updateToggleVideoButton()
            
            guard !isLeavingCall else {
                return
            }
            
            switch ownVideoMuteState {
            case .changing:
                break
            case .muted:
                groupCallActor?.dependencies.notificationPresenterWrapper
                    .presentGroupCallNotification(type: .videoMuted)
            case .unmuted:
                groupCallActor?.dependencies.notificationPresenterWrapper
                    .presentGroupCallNotification(type: .videoUnmuted)
            }
        }
    }
        
    // MARK: - Private Properties

    private var participantsList = [ViewModelParticipant]()
    
    private let bannerAndButtonQueue: AsyncStream<GroupCallUIEvent>
    private let bannerAndButtonContinuation: AsyncStream<GroupCallUIEvent>.Continuation
    
    private var periodicUIRefreshTask: Task<Void, Never>?
    
    private weak var viewDelegate: GroupCallViewModelDelegate?
    private weak var toolBarDelegate: GroupCallToolbarDelegate?
    
    private var localParticipant: ViewModelParticipant? = nil
    
    /// True as soon as End-Call Button was pressed
    private var isLeavingCall = false
    
    // MARK: - Lifecycle

    init(groupCallActor: GroupCallActor) {
        self.groupCallActor = groupCallActor
        
        (self.bannerAndButtonQueue, self.bannerAndButtonContinuation) = AsyncStream<GroupCallUIEvent>.makeStream()
        DDLogNotice("[GroupCall] Created view model with address \(Unmanaged.passUnretained(self).toOpaque())")
        
        subscribeToEvents()
    }
    
    deinit {
        bannerAndButtonContinuation.finish()
    }
    
    // MARK: - Public setter
    
    func setToolBarDelegate(_ delegate: GroupCallToolbarDelegate) {
        toolBarDelegate = delegate
    }
    
    func setViewDelegate(_ delegate: GroupCallViewModelDelegate) {
        viewDelegate = delegate
    }
    
    // MARK: - Public functions

    public func getCallStartDate() async -> Date? {
        await groupCallActor?.approximateCallStartDateUI
    }
    
    func participant(for id: ParticipantID) -> ViewModelParticipant? {
        participantsList.first { $0.id == id }
    }

    var numberOfParticipants: Int {
        participantsList.count
    }
    
    // MARK: - ToolBar button actions
    
    func endCall() {
        isLeavingCall = true
        Task {
            guard let groupCallActor else {
                await self.leaveConfirmed()
                return
            }
            
            guard await groupCallActor.stopCall() else {
                await leaveConfirmed()
                return
            }
        }
    }
        
    func toggleOwnVideo() async throws {
        let currentState = ownVideoMuteState
        ownVideoMuteState = .changing

        switch currentState {
        case .changing:
            break
        case .muted:
            try await groupCallActor?.toggleOwnVideo(false)
        case .unmuted:
            try await groupCallActor?.toggleOwnVideo(true)
        }
    }
        
    func toggleOwnAudio() async throws {
        let currentState = ownAudioMuteState
        ownAudioMuteState = .changing

        switch currentState {
        case .changing:
            break
        case .muted:
            try await groupCallActor?.toggleOwnAudio(false)
        case .unmuted:
            try await groupCallActor?.toggleOwnAudio(true)
        }
    }
    
    func switchCamera() async {
        await groupCallActor?.switchCamera()
    }
    
    // MARK: - Private Functions

    private func subscribeToEvents() {
        // TODO: (IOS-4047) Is `detached` what we want here?
        Task.detached { [weak self] in
            guard let self, let groupCallActor = self.groupCallActor else {
                return
            }
            
            for await item in groupCallActor.uiQueue {
                await self.handle(item)
            }
        }
    }
    
    private func handle(_ event: GroupCallUIEvent) async {
        switch event {
        case let .error(err):
            DDLogError("[GroupCall] [GroupCallUI] An error occurred \(err)")
            yieldButtonBannerState()
            
        case .connecting:
            DDLogNotice("[GroupCall] [GroupCallUI] Start connecting")
            await updateNavigationBar(for: .connecting)
            yieldButtonBannerState()
            
        case .joining:
            DDLogNotice("[GroupCall] [GroupCallUI] Start joining")
            await updateNavigationBar(for: .joining)
            yieldButtonBannerState()
            
        case .connected:
            DDLogNotice("[GroupCall] [GroupCallUI] Start connected")
            await updateNavigationBar(for: .connected)
            startPeriodicUIUpdatesIfNeeded()
            yieldButtonBannerState()
            await groupCallActor?.connectedConfirmed()
        
        case let .callStateChanged(showButton):
            buttonBannerObserver.stateContinuation.yield(showButton)
            
        case let .add(newParticipant):
            DDLogNotice("[GroupCall] [GroupCallUI] Add participant \(newParticipant.id)")
            await add(newParticipant)
            viewDelegate?.updateCollectionViewLayout()
            yieldButtonBannerState()
            
        case let .remove(participantID):
            DDLogNotice("[GroupCall] [GroupCallUI] Remove participant \(participantID)")
            await remove(participantID)
            viewDelegate?.updateCollectionViewLayout()
            yieldButtonBannerState()
        
        case let .participantStateChange(participant, change):
            DDLogNotice("[GroupCall] Reconfigure participant \(participant.id)")
            
            handleMuteStateChange(for: participant, change: change)
            
            await publishSnapshot(reconfigure: [participant])
            yieldButtonBannerState()
            
        case let .addLocalParticipant(localParticipant):
            self.localParticipant = localParticipant
            await add(localParticipant)
            yieldButtonBannerState()
            
        case let .audioMuteChange(state):
            // TODO: Check if local participant exists
            ownAudioMuteState = state
            localParticipant?.audioMuteState = state == .muted ? .muted : .unmuted
            await publishSnapshot(reconfigure: [localParticipant!.id])
           
        case let .videoMuteChange(state):
            // TODO: Check if local participant exists
            ownVideoMuteState = state
            localParticipant?.videoMuteState = state == .muted ? .muted : .unmuted
            await publishSnapshot(reconfigure: [localParticipant!.id])

        case let .videoCameraChange(position):
            localParticipant?.localParticipant?.localCameraPosition = position
            await publishSnapshot(reconfigure: [localParticipant!.id])
            
        case .leaveConfirmed:
            await leaveConfirmed()
            yieldButtonBannerState()
            await groupCallActor?.callStopSignalContinuation?.finish()
            
        case .pop:
            await viewDelegate?.dismissGroupCallView()
        }
    }
    
    private func yieldButtonBannerState() {
        Task.detached { [self] in
            guard let groupCallActor else {
                buttonBannerObserver.stateContinuation.yield(.hidden)
                return
            }
            
            // TODO: Is the start date correct?
            let state = await GroupCallBannerButtonInfo(
                numberOfParticipants: participantsList.count,
                startDate: getCallStartDate() ?? .now,
                joinState: groupCallActor.joinState()
            )
            buttonBannerObserver.stateContinuation.yield(.visible(state))
        }
    }
    
    private func updateNavigationBar(for event: GroupCallUIEvent) async {
        var title: String?
        switch event {
        case .joining:
            title = groupCallActor?.dependencies.groupCallBundleUtil
                .localizedString(for: "group_call_navbar_state_joining")
        case .connecting:
            title = groupCallActor?.dependencies.groupCallBundleUtil
                .localizedString(for: "group_call_navbar_state_connecting")
        case .connected:
            title = groupCallActor?.dependencies.groupCallBundleUtil
                .localizedString(for: "group_call_navbar_state_connected")
        default:
            break
        }
        
        let update = GroupCallNavigationBarContentUpdate(title: title, participantCount: nil, timeString: nil)
        
        await viewDelegate?.updateNavigationContent(update)
    }
    
    private func add(_ participant: ViewModelParticipant) async {
        DDLogNotice("[ViewModel] \(#function)")
        participantsList.append(participant)
        
        await publishSnapshot()
    }
    
    private func remove(_ participantID: ParticipantID) async {
        DDLogNotice("[ViewModel] \(#function)")
        participantsList.removeAll(where: { $0.id == participantID })
        
        await publishSnapshot()
    }
    
    private func handleMuteStateChange(for participant: ParticipantID, change: ParticipantStateChange) {
        
        guard let participant = participantsList.first(where: { $0.id == participant }) else {
            DDLogNotice("[ViewModel] \(#function)")
            return
        }
        
        switch change {
        case let .audioState(muteState):
            participant.audioMuteState = muteState
        case let .videoState(muteState):
            participant.videoMuteState = muteState
        }
    }

    @MainActor
    private func publishSnapshot(reconfigure: [ParticipantID] = []) {
        DDLogNotice("[ViewModel] \(#function)")
        var newSnapshot = Snapshot()
        newSnapshot.appendSections([.main])
        newSnapshot.appendItems(participantsList.map(\.id))
        newSnapshot.reconfigureItems(reconfigure)
        
        snapshotPublisher = newSnapshot
    }

    // MARK: - Cell Updates
    
    func addRendererView(for participantID: ParticipantID, rendererView: RTCMTLVideoView) async {
        guard let participant = participantsList.first(where: { $0.id == participantID }) else {
            DDLogNotice("[GroupCall] [Renderer] Could not get participant")
            return
        }
        
        var track: RTCVideoTrack?
        
        if participant == localParticipant {
            track = await groupCallActor?.localContext()
        }
        else {
            track = await groupCallActor?.remoteContext(for: participantID)?.cameraVideoContext?.track
        }
        
        guard let track else {
            DDLogNotice("[GroupCall] [Renderer] Could not get track")
            return
        }
        
        track.isEnabled = true
        track.add(rendererView)
        DDLogNotice("[GroupCall] [Renderer] Added renderer to track")
    }
    
    func removeRendererView(for participantID: ParticipantID, rendererView: RTCMTLVideoView) async {
        
        // Local Participant
        if participantID == localParticipant?.id, let track = await groupCallActor?.localContext() {
            track.remove(rendererView)
            return
        }
        
        // Remote Participant
        if let remoteTrack = await groupCallActor?.remoteContext(for: participantID)?.cameraVideoContext?.track {
            remoteTrack.remove(rendererView)
        }
    }
    
    func unsubscribeVideo(for participant: ParticipantID) async {
        await groupCallActor?.unsubscribeVideo(for: participant)
    }
    
    func subscribeVideo(for participant: ParticipantID) async {
        await groupCallActor?.subscribeVideo(for: participant)
    }
}

// MARK: - Periodic Callbacks

extension GroupCallViewModel {
    func startPeriodicUIUpdatesIfNeeded() {
        guard periodicUIRefreshTask == nil else {
            return
        }
        
        periodicUIRefreshTask = Task.detached { [weak self] in
            let refresh = {
                
                guard let viewDelegate = self?.viewDelegate else {
                    self?.periodicUIRefreshTask?.cancel()
                    self?.periodicUIRefreshTask = nil
                    return
                }
                
                guard let startDate = await self?.getCallStartDate() else {
                    return
                }
                
                guard let numberOfParticipants = self?.numberOfParticipants else {
                    return
                }
                
                let diff = Date().timeIntervalSince(startDate)
                let timeString = self?.groupCallActor?.dependencies.groupCallDateFormatter.timeFormatted(diff)
                
                let update = GroupCallNavigationBarContentUpdate(
                    title: self?.groupCallActor?.group.groupName,
                    participantCount: numberOfParticipants,
                    timeString: timeString
                )
                await viewDelegate.updateNavigationContent(update)
            }
            
            while !Task.isCancelled {
                DDLogNotice("[GroupCall] Update NavigationBar")
                await refresh()
                
                try? await Task.sleep(seconds: 1)
            }
        }
    }
    
    private func leaveConfirmed() async {
        participantsList = []
        
        // TODO: This is not great and it also posts notifications for the reset even though that's not at all what the user did
        ownAudioMuteState = .muted
        ownVideoMuteState = .muted
        
        periodicUIRefreshTask?.cancel()
        periodicUIRefreshTask = nil // Otherwise the update task will not be recreated the next time
        
        await publishSnapshot()
        await viewDelegate?.dismissGroupCallView()
    }
}
