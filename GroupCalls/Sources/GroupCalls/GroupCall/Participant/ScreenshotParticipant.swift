//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import Foundation
import ThreemaEssentials
import UIKit

/// Only use for screenshots
class ScreenshotParticipant: ViewModelParticipant {
    
    nonisolated let participantID: ParticipantID
    nonisolated let threemaIdentity: ThreemaIdentity
    let dependencies: Dependencies
    
    nonisolated lazy var displayName: String = dependencies.groupCallParticipantInfoFetcher
        .fetchDisplayName(for: threemaIdentity)
    
    nonisolated lazy var avatar: UIImage? = dependencies.groupCallParticipantInfoFetcher
        .fetchAvatar(for: threemaIdentity)
    
    nonisolated lazy var idColor: UIColor = dependencies.groupCallParticipantInfoFetcher
        .fetchIDColor(for: threemaIdentity)
    
    var audioMuteState: MuteState = .muted
    var videoMuteState: MuteState = .muted
    
    func setVideoMuteState(to state: MuteState) async {
        videoMuteState = state
    }
    
    func setAudioMuteState(to state: MuteState) async {
        audioMuteState = state
    }
    
    // MARK: - Lifecycle

    init(
        participantID: ParticipantID,
        threemaIdentity: ThreemaIdentity,
        dependencies: Dependencies,
        audioMuteState: MuteState,
        videoMuteState: MuteState
    ) {
        guard dependencies.isRunningForScreenshots else {
            fatalError(
                "[GroupCall] Tried to initialize ScreenshotParticipant even though we are not running for screenshots"
            )
        }
        
        self.participantID = participantID
        self.threemaIdentity = threemaIdentity
        self.dependencies = dependencies
        self.audioMuteState = audioMuteState
        self.videoMuteState = videoMuteState
    }
}
