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

import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
import UIKit
import WebRTC

/// View model for a group call
///
/// - Warning: This model lives from the the first join of a group call until the call ends or the app is terminated
///            (i.e. if you join, leave and join again (without terminating the app) the same model is used). (IOS-4073)
public final class GroupCallViewModel: Sendable {
    
    typealias DataSource = GroupCallCollectionViewDataSource
    typealias Snapshot = NSDiffableDataSourceSnapshot<DataSource.Section, ParticipantID>
    
    // MARK: - Public Properties

    weak var groupCallActor: GroupCallActor?
    
    @Published var snapshotPublisher = Snapshot()

    private(set) var ownAudioMuteState: OwnMuteState = GroupCallConfiguration.LocalInitialMuteState.audio {
        didSet {
            toolBarDelegate?.updateToggleAudioButton()
            
            guard oldValue != ownAudioMuteState else {
                return
            }
            
            guard AVAudioSession.sharedInstance().recordPermission == .granted else {
                return
            }
            
            // TODO: (IOS-4073) This workaround should be removed as the view model should only live as long as we've joined the call
            // Workaround that no notification is shown when the state is reset during leaving a call
            Task(priority: .userInitiated) {
                guard await (groupCallActor?.joinState() ?? .notJoined) != .notJoined else {
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
    }
    
    private(set) var ownVideoMuteState: OwnMuteState = GroupCallConfiguration.LocalInitialMuteState.video {
        didSet {
            toolBarDelegate?.updateToggleVideoButton()
            
            guard oldValue != ownAudioMuteState else {
                return
            }
            
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                return
            }
            
            // TODO: (IOS-4073) This workaround should be removed as the view model should only live as long as we've joined the call
            // Workaround that no notification is shown when the state is reset during leaving a call
            Task(priority: .userInitiated) {
                guard await (groupCallActor?.joinState() ?? .notJoined) != .notJoined else {
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
    }
        
    // MARK: - Private Properties

    private var participantsList = [ViewModelParticipant]()
    
    private var periodicUIRefreshTask: Task<Void, Never>?
    
    private weak var viewDelegate: GroupCallViewModelDelegate?
    private weak var toolBarDelegate: GroupCallToolbarDelegate?
    
    private var localParticipant: LocalParticipant?
    
    // Screenshot
    private var isRunningForScreenshots = false
    private var screenshotGroupName = ""
    
    // MARK: - Lifecycle

    init(groupCallActor: GroupCallActor) {
        self.groupCallActor = groupCallActor
        
        DDLogNotice("[GroupCall] Created view model with address \(Unmanaged.passUnretained(self).toOpaque())")
        
        subscribeToEvents()
    }
    
    /// Only use when running screenshots
    init(
        screenshotGroupName: String,
        localParticipant: LocalParticipant,
        participantsList: [ViewModelParticipant],
        dependencies: Dependencies
    ) {
        guard dependencies.isRunningForScreenshots else {
            fatalError(
                "[GroupCall] Tried to initialize GroupCallViewModel for screenshots even though we are not running for screenshots"
            )
        }
        
        self.localParticipant = localParticipant
        self.participantsList = participantsList
        self.isRunningForScreenshots = true
        self.screenshotGroupName = screenshotGroupName
    }
    
    // MARK: - Public setter
    
    func setToolBarDelegate(_ delegate: GroupCallToolbarDelegate) {
        toolBarDelegate = delegate
    }
    
    func setViewDelegate(_ delegate: GroupCallViewModelDelegate) {
        viewDelegate = delegate
    }
    
    // MARK: - Public functions
    
    func participant(for participantID: ParticipantID) -> ViewModelParticipant? {
        participantsList.first { $0.participantID == participantID }
    }

    var numberOfParticipants: Int {
        participantsList.count
    }
    
    func updateForScreenshots() {
        guard isRunningForScreenshots else {
            assertionFailure("This should only be called during screenshots")
            return
        }
        
        Task {
            self.ownVideoMuteState = .unmuted
            self.ownAudioMuteState = .unmuted
            
            let update = GroupCallNavigationBarContentUpdate(
                title: screenshotGroupName,
                participantCount: 4,
                timeInterval: 546
            )
            await self.viewDelegate?.updateNavigationContent(update)
            
            await publishSnapshot()
        }
    }
    
    // MARK: - ToolBar button actions
    
    func leaveCallButtonTapped() {
        /// **Leave Call** 1. The user tapped the leave button, we begin leaving the call
        DDLogNotice("[GroupCall] User tapped leave call button")
        
        Task(priority: .userInitiated) {
            guard !isRunningForScreenshots else {
                // Just dismiss the view
                await viewDelegate?.dismissGroupCallView(animated: true)
                return
            }
            
            // In our tests no dismiss was need here as the call to `leaveCall()` from `Ending` was happening enough
            // fast. If there is an observable delay from when the button is tapped and the view disappears we might
            // consider calling dismiss here or even directly `leaveCall()` for a first time. (It will still be needed
            // in `Ending`.)
            
            /// 1.1 Pass on info to `GroupCallActor
            await groupCallActor?.beginLeaveCall()
        }
    }
        
    func toggleOwnVideo() async {
        let currentState = ownVideoMuteState
        ownVideoMuteState = .changing
        
        switch currentState {
        case .changing:
            break
        case .muted:
            await groupCallActor?.toggleOwnVideo(false)
        case .unmuted:
            await groupCallActor?.toggleOwnVideo(true)
        }
    }
        
    func toggleOwnAudio() async {
        let currentState = ownAudioMuteState
        ownAudioMuteState = .changing
        
        switch currentState {
        case .changing:
            break
        case .muted:
            await groupCallActor?.toggleOwnAudio(false)
        case .unmuted:
            await groupCallActor?.toggleOwnAudio(true)
        }
    }
        
    func switchCamera() async {
        await groupCallActor?.switchCamera()
    }
    
    // MARK: - Private Functions

    private func subscribeToEvents() {
        // TODO: (IOS-4047) Is `detached` what we want here?
        Task.detached { [weak self] in
            guard let self, let groupCallActor else {
                return
            }
            
            for await item in groupCallActor.uiQueue {
                await handle(item)
            }
        }
    }
    
    private func handle(_ event: GroupCallUIEvent) async {
        switch event {
        case let .error(err):
            DDLogError("[GroupCall] [GroupCallUI] An error occurred: \(err)")
            
        case .connecting:
            DDLogNotice("[GroupCall] [GroupCallUI] Start connecting")
            await updateNavigationBar(for: .connecting)
            
        case .joining:
            DDLogNotice("[GroupCall] [GroupCallUI] Start joining")
            await updateNavigationBar(for: .joining)
            
        case .connected:
            DDLogNotice("[GroupCall] [GroupCallUI] Start connected")
            await updateNavigationBar(for: .connected)
            startPeriodicUIUpdatesIfNeeded()
            
        case let .remove(participantID):
            DDLogNotice("[GroupCall] [GroupCallUI] Remove participant \(participantID)")
            await remove(participantID)
            Task { @MainActor in
                viewDelegate?.updateCollectionViewLayout()
            }
        
        case let .participantStateChange(participantID, change):
            DDLogNotice("[GroupCall] Reconfigure participant \(participantID)")
            
            await handleMuteStateChange(for: participantID, change: change)
            
            await publishSnapshot(reconfigure: [participantID])
            
        case let .add(viewModelParticipant):
            if let localParticipant = viewModelParticipant as? LocalParticipant {
                self.localParticipant = localParticipant
            }
            await add(viewModelParticipant)
            
            Task { @MainActor in
                viewDelegate?.updateCollectionViewLayout()
            }
            
        case let .audioMuteChange(newState):
            await handleOwnAudioMuteStateChange(newState: newState)
           
        case let .videoMuteChange(newState):
            await handleOwnVideoMuteStateChange(newState: newState)

        case let .videoCameraChange(position):
            guard let localParticipant else {
                return
            }
            await localParticipant.setActiveCameraPosition(to: position)
            await publishSnapshot(reconfigure: [localParticipant.participantID])
            
        case .forceDismissGroupCallViewController:
            await viewDelegate?.dismissGroupCallView(animated: false)
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
        
        let update = GroupCallNavigationBarContentUpdate(
            title: title,
            participantCount: nil,
            timeInterval: TimeInterval(0)
        )
        
        await viewDelegate?.updateNavigationContent(update)
    }
    
    private func add(_ participant: ViewModelParticipant) async {
        // TODO: (IOS-3857) Are these logs still needed?
        DDLogNotice("[ViewModel] \(#function)")
        participantsList.append(participant)
        
        await publishSnapshot()
    }
    
    private func remove(_ participantID: ParticipantID) async {
        DDLogNotice("[ViewModel] \(#function)")
        participantsList.removeAll(where: { $0.participantID == participantID })
        
        await publishSnapshot()
    }
    
    private func handleOwnVideoMuteStateChange(newState: OwnMuteState) async {
        guard let localParticipant else {
            return
        }
        
        guard ownVideoMuteState != newState else {
            return
        }
        
        // Check if we have permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            await AVCaptureDevice.requestAccess(for: .video)
            await handleOwnVideoMuteStateChange(newState: newState)
            
        case .restricted, .denied:
            await viewDelegate?.showRecordVideoPermissionAlert()
            ownVideoMuteState = .muted
            
        case .authorized:
            ownVideoMuteState = newState
            let muteState: MuteState = newState == .muted ? .muted : .unmuted
            await localParticipant.setVideoMuteState(to: muteState)
            
            await publishSnapshot(reconfigure: [localParticipant.participantID])
            
        @unknown default:
            assertionFailure()
        }
    }
    
    private func handleOwnAudioMuteStateChange(newState: OwnMuteState) async {
        guard let localParticipant else {
            return
        }
        
        guard ownAudioMuteState != newState else {
            return
        }
        
        // Check if we have permission
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            await AVAudioSession.sharedInstance().requestRecordPermission()
            await handleOwnAudioMuteStateChange(newState: newState)
            
        case .denied:
            await viewDelegate?.showRecordAudioPermissionAlert()
            ownAudioMuteState = .muted
            
        case .granted:
            ownAudioMuteState = newState
            let muteState: MuteState = newState == .muted ? .muted : .unmuted
            await localParticipant.setAudioMuteState(to: muteState)
            await publishSnapshot(reconfigure: [localParticipant.participantID])
            
        @unknown default:
            assertionFailure()
        }
    }
    
    private func handleMuteStateChange(for participantID: ParticipantID, change: ParticipantStateChange) async {
        
        guard let participant = participant(for: participantID) else {
            DDLogNotice("[ViewModel] \(#function)")
            return
        }
        
        switch change {
        case let .audioState(muteState):
            await participant.setAudioMuteState(to: muteState)
        case let .videoState(muteState):
            await participant.setVideoMuteState(to: muteState)
        case let .screenState(muteState):
            await participant.setScreenMuteState(to: muteState)
        }
    }

    @MainActor
    private func publishSnapshot(reconfigure: [ParticipantID] = []) {
        DDLogNotice("[ViewModel] \(#function)")
        
        let newParticipantIDs = participantsList.map(\.participantID)
        
        // It is illegal to reconfigure an item that is not in the snapshot. Thus we filter the list
        // TODO: (IOS-4162) This can be removed if teardown is implemented correctly
        let filteredReconfigureParticipantIDs = Set(newParticipantIDs).intersection(reconfigure)
        if filteredReconfigureParticipantIDs.count != reconfigure.count {
            DDLogWarn("[GroupCall] Trying to reconfigure participants that are not in the participants list")
        }
        
        var newSnapshot = Snapshot()
        newSnapshot.appendSections([.main])
        newSnapshot.appendItems(newParticipantIDs)
        newSnapshot.reconfigureItems(Array(filteredReconfigureParticipantIDs))
        
        snapshotPublisher = newSnapshot
    }
    
    // MARK: - Cell Updates
    
    func addRendererView(for participantID: ParticipantID, rendererView: RTCMTLVideoView) async {
        guard let participant = participantsList.first(where: { $0.participantID == participantID }) else {
            DDLogNotice("[GroupCall] [Renderer] Could not get participant")
            return
        }
        
        let track: RTCVideoTrack? =
            if participant.participantID == localParticipant?.participantID {
                await groupCallActor?.localContext()
            }
            else {
                await groupCallActor?.remoteContext(for: participantID)?.cameraVideoContext?.track
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
        if participantID == localParticipant?.participantID, let track = await groupCallActor?.localContext() {
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
                
                guard let strongSelf = self else {
                    return
                }
                
                guard await strongSelf.groupCallActor?.joinState() == .joined else {
                    return
                }
                
                guard let viewDelegate = strongSelf.viewDelegate else {
                    strongSelf.periodicUIRefreshTask?.cancel()
                    strongSelf.periodicUIRefreshTask = nil
                    return
                }
                
                let numberOfParticipants = strongSelf.numberOfParticipants
                let timeInterval = await Date().timeIntervalSince(strongSelf.groupCallActor?.callStartDate() ?? .now)

                let update = GroupCallNavigationBarContentUpdate(
                    title: strongSelf.groupCallActor?.group.groupName,
                    participantCount: numberOfParticipants,
                    timeInterval: timeInterval
                )
                await viewDelegate.updateNavigationContent(update)
            }
            
            while !Task.isCancelled {
                DDLogNotice("[GroupCall] Update NavigationBar")
                await refresh()
                
                do {
                    try await Task.sleep(seconds: 1)
                }
                catch {
                    self?.periodicUIRefreshTask = nil
                }
            }
        }
    }
    
    public func leaveCall() async {
        DDLogNotice("[GroupCall] Leave: GroupCallViewModel")

        /// 1.1 Remove all participants and publish the last snapshot, this is needed when the users wants to rejoin the
        /// call
        participantsList.removeAll()
        await publishSnapshot()
        
        /// 1.2 Dismiss the view
        await viewDelegate?.dismissGroupCallView(animated: true)
        
        /// 1.3 Reset audio & video state
        // TODO: (IOS-4073) This state should always be reset to the appropriate values when a call is joined
        // We dispatch the mutes through the `uiQueue` and after the initiated dismiss of the call view to reduce the
        // change of a race condition of a later unmute action
        groupCallActor?.uiContinuation.yield(.audioMuteChange(.muted))
        groupCallActor?.uiContinuation.yield(.videoMuteChange(.muted))
        // The WebRTC tracks will be removed in `Ending`
        
        /// 1.4 Reset refresh Task
        periodicUIRefreshTask?.cancel()
        periodicUIRefreshTask = nil
    }
    
    public func teardown() async {
        DDLogNotice("[GroupCall]] Teardown: GroupCallViewModel")
        
        // Participants
        // TODO: (IOS-4047) TaskGroup? Do we even need to unsubscribe?
        for participant in participantsList {
            await unsubscribeVideo(for: participant.participantID)
        }
        
        localParticipant = nil
    }
}

extension AVAudioSession {
    func requestRecordPermission() async {
        await withCheckedContinuation { continuation in
            requestRecordPermission { _ in
                continuation.resume()
            }
        }
    }
}
