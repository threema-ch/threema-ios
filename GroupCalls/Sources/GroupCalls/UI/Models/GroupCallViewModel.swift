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
    
    // MARK: - Public Properties

    weak var groupCallActor: GroupCallActor?
    
    @Published var snapshotPublisher = NSDiffableDataSourceSnapshot<
        GroupCallCollectionViewDataSource.Section,
        ParticipantID
    >()

    public let buttonBannerObserver = AsyncStreamContinuationToSharedPublisher<GroupCallButtonBannerState>()

    var ownAudioMuteState: OwnMuteState = GroupCallConfiguration.LocalInitialMuteState.audio {
        didSet {
            toolBarDelegate?.updateToggleAudioButton()

            guard !endCallPressed else {
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
            
            guard !endCallPressed else {
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
    
    var isOnScreenVisible: Bool {
        viewDelegate != nil
    }
    
    weak var viewDelegate: GroupCallViewProtocol?
    weak var toolBarDelegate: GroupCallToolbarDelegate?
    
    // MARK: - Private Properties

    fileprivate typealias Snapshot = NSDiffableDataSourceSnapshot<
        GroupCallCollectionViewDataSource.Section,
        ParticipantID
    >

    fileprivate var participantsList = [ViewModelParticipant]()
    
    private let bannerAndButtonQueue: AsyncStream<GroupCallUIEvent>
    private let bannerAndButtonContinuation: AsyncStream<GroupCallUIEvent>.Continuation
    
    var periodicUIUpdateTask: Task<Void, Never>?
    
    private var localParticipant: ViewModelParticipant? = nil
    private var endCallPressed = false
    
    // MARK: - Lifecycle

    init(groupCallActor: GroupCallActor) {
        self.groupCallActor = groupCallActor
        
        (self.bannerAndButtonQueue, self.bannerAndButtonContinuation) = AsyncStream<GroupCallUIEvent>.makeStream()
        DDLogNotice(
            "[GroupCall] [GroupCallUI] Created view model with address \(Unmanaged.passUnretained(self).toOpaque())"
        )
        
        subscribeToEvents()
    }
    
    deinit {
        bannerAndButtonContinuation.finish()
    }
    
    // MARK: - Public Functions

    public func getCallStartDate() async -> Date? {
        await groupCallActor?.approximateCallStartDateUI
    }
    
    func participant(for id: ParticipantID) -> ViewModelParticipant? {
        participantsList.first { $0.id == id }
    }

    func getNumberOfParticipants() -> Int {
        participantsList.count
    }
    
    // MARK: - ToolBar Button Actions
    
    public func endCall() {
        endCallPressed = true
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
        Task.detached { [weak self] in
            guard let self else {
                return
            }
            guard let groupCallActor = self.groupCallActor else {
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
            
        case let .add(newParticipant):
            DDLogNotice("[GroupCall] [GroupCallUI] Add participant \(newParticipant.id)")
            await add(newParticipant)
            await viewDelegate?.updateLayout()
            yieldButtonBannerState()
            
        case let .remove(participantID):
            DDLogNotice("[GroupCall] [GroupCallUI] Remove participant \(participantID)")
            await remove(participantID)
            await viewDelegate?.updateLayout()
            yieldButtonBannerState()
            
        case .reload:
            await publishSnapshot()
            yieldButtonBannerState()
            
        case let .participantStateChange(participant, change):
            DDLogNotice("[GroupCall] Reconfigure participant \(participant.id)")
            
            handleMuteStateChange(for: participant, change: change)
            
            await publishSnapshot(reconfigure: [participant])
            yieldButtonBannerState()

        case .leaveConfirmed:
            await leaveConfirmed()
            yieldButtonBannerState()
            await groupCallActor?.callStopSignalContinuation?.finish()
            
        case let .stateChanged(showButton):
            buttonBannerObserver.stateContinuation.yield(showButton)
            
        case .pop:
            await viewDelegate?.close()
            
        case let .addLocalParticipant(localParticipant):
            self.localParticipant = localParticipant
            await add(localParticipant)
            yieldButtonBannerState()
            
        case let .audioMuteChange(state):
            ownAudioMuteState = state
            localParticipant?.audioMuteState = state == .muted ? .muted : .unmuted
            await publishSnapshot(reconfigure: [localParticipant!.id])
           
        case let .videoMuteChange(state):
            ownVideoMuteState = state
            localParticipant?.videoMuteState = state == .muted ? .muted : .unmuted
            await publishSnapshot(reconfigure: [localParticipant!.id])
        }
    }
    
    private func yieldButtonBannerState() {
        Task.detached { [self] in
            guard let groupCallActor else {
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
    
    func addMyself(videoTrack: RTCVideoTrack) { }
    
    func pop() async {
        await viewDelegate?.close()
    }
    
    private func updateNavigationBar(for event: GroupCallUIEvent) async {
        var title: String?
        switch event {
        case .joining:
            title = groupCallActor?.dependencies.groupCallBundleUtil
                .localizedGCString(for: "group_call_navbar_state_joining")
        case .connecting:
            title = groupCallActor?.dependencies.groupCallBundleUtil
                .localizedGCString(for: "group_call_navbar_state_connecting")
        case .connected:
            title = groupCallActor?.dependencies.groupCallBundleUtil
                .localizedGCString(for: "group_call_navbar_state_connected")
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
        
        guard var participant = participantsList.first(where: { $0.id == participant }) else {
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
        newSnapshot.appendItems(participantsList.map(\.id), toSection: .main)
        newSnapshot.reconfigureItems(reconfigure)
        
        snapshotPublisher = newSnapshot
    }
}

// MARK: - GroupCallCellModelProtocol

extension GroupCallViewModel: GroupCallCellModelProtocol {
    func rendererView(for participantID: ParticipantID, rendererView: RTCMTLVideoView) async -> Bool {
        guard let participant = participantsList.first(where: { $0.id == participantID }) else {
            DDLogNotice("[GroupCall] [Renderer] Could not get participant")
            return false
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
            return false
        }
        
        track.isEnabled = true
        track.add(rendererView)
        DDLogNotice("[GroupCall] [Renderer] Added renderer to track")
        
        return true
    }
    
    func remove(for participantID: ParticipantID, rendererView: RTCMTLVideoView) async {
        
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
    
    func unsubscribeAudio(for participant: ParticipantID) { }
    
    func subscribeAudio(for participant: ParticipantID) { }
    
    func muteAudio() { }
    
    func unmuteAudio() { }
    
    func muteVideo() { }
    
    func unmuteVideo() { }
}

// MARK: Periodic Callbacks

extension GroupCallViewModel {
    func startPeriodicUIUpdatesIfNeeded() {
        guard periodicUIUpdateTask == nil else {
            return
        }
        
        periodicUIUpdateTask = Task.detached { [weak self] in
            let up = {
                
                guard let viewDelegate = self?.viewDelegate else {
                    self?.periodicUIUpdateTask?.cancel()
                    self?.periodicUIUpdateTask = nil
                    return
                }
                
                guard let startDate = await self?.getCallStartDate() else {
                    return
                }
                
                guard let numberOfParticipants = self?.getNumberOfParticipants() else {
                    return
                }
                
                let diff = Int(Date().timeIntervalSince(startDate))
                let timeString = self?.groupCallActor?.dependencies.groupCallDateFormatter.timeFormatted(diff)
                
                let update = GroupCallNavigationBarContentUpdate(
                    title: self?.groupCallActor?.group.groupName,
                    participantCount: numberOfParticipants,
                    timeString: timeString
                )
                await viewDelegate.updateNavigationContent(update)
            }
            
            while !Task.isCancelled {
                if #available(iOS 16.0, *) {
                    try? await Task.sleep(for: .seconds(1))
                }
                else {
                    // Fallback on earlier versions
                    try? await Task.sleep(nanoseconds: 1 * 1000 * 1000 * 1000)
                }
                
                DDLogNotice("[GroupCall] Update NavigationBar")
                await up()
            }
        }
    }
    
    private func leaveConfirmed() async {
        participantsList = []
        
        // TODO: This is not great and it also posts notifications for the reset even though that's not at all what the user did
        ownAudioMuteState = .muted
        ownVideoMuteState = .muted
        
        await publishSnapshot()
        await viewDelegate?.close()
    }
}
