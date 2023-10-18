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

import Foundation
import UIKit

public class ViewModelParticipant {
    
    let participantID: ParticipantID
    let threemaID: ThreemaID
    
    let name: String
    let avatar: UIImage?
    let idColor: UIColor
    // TODO: (IOS-4052) Can we get rid of this by wrapping this call in a enum on the usage side?
    weak var localParticipant: LocalParticipant?

    let dependencies: Dependencies
    
    var audioMuteState: MuteState = .muted
    var videoMuteState: MuteState = .muted
    
    init(remoteParticipant: RemoteParticipant, name: String?, avatar: UIImage?, idColor: UIColor) async {
        let threemaID = await remoteParticipant.threemaIdentity!
        self.participantID = await remoteParticipant.getID()
        self.name = name ?? threemaID.id
        self.threemaID = threemaID
        self.avatar = avatar
        self.idColor = idColor
        self.localParticipant = nil
        self.dependencies = remoteParticipant.dependencies
    }
    
    init(localParticipant: LocalParticipant, name: String?, avatar: UIImage?, idColor: UIColor) async {
        let threemaID = try! ThreemaID(id: localParticipant.identity)
        self.participantID = localParticipant.participantID
        self.name = name ?? threemaID.id
        self.threemaID = threemaID
        self.avatar = avatar
        self.idColor = idColor
        self.localParticipant = localParticipant
        self.dependencies = localParticipant.dependencies
        
        self.audioMuteState = GroupCallConfiguration.LocalInitialMuteState.audio.muteState()
        self.videoMuteState = GroupCallConfiguration.LocalInitialMuteState.video.muteState()
    }
    
    // MARK: - Accessibility
    
    public func cellAccessibilityString() -> String {
        "\(name), \(cellAccessibilityAudioString()), \(cellAccessibilityVideoString())"
    }
    
    private func cellAccessibilityVideoString() -> String {
        switch videoMuteState {
        case .muted:
            return dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_video_disabled")
        case .unmuted:
            return dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_video_enabled")
        }
    }
    
    func cellAccessibilityAudioString() -> String {
        switch audioMuteState {
        case .muted:
            return dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_audio_disabled")
        case .unmuted:
            return dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_audio_enabled")
        }
    }
}

// MARK: - Equatable

extension ViewModelParticipant: Equatable {
    public static func == (lhs: ViewModelParticipant, rhs: ViewModelParticipant) -> Bool {
        lhs.participantID == rhs.participantID && lhs.threemaID == rhs.threemaID && lhs.name == rhs.name && lhs
            .avatar == rhs.avatar && lhs
            .idColor == rhs.idColor && lhs.audioMuteState == rhs.audioMuteState && lhs.videoMuteState == rhs
            .videoMuteState
    }
}
