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

@GlobalGroupCallActor
protocol ViewModelParticipant: Participant {
    nonisolated var threemaIdentity: ThreemaIdentity { get }
    nonisolated var dependencies: Dependencies { get }

    nonisolated var displayName: String { get }
    nonisolated var profilePicture: UIImage { get }
    nonisolated var idColor: UIColor { get }

    var audioMuteState: MuteState { get }
    var videoMuteState: MuteState { get }
    
    func setVideoMuteState(to state: MuteState) async
    func setAudioMuteState(to state: MuteState) async

    func cellAccessibilityLabel() -> String
}

@GlobalGroupCallActor
extension ViewModelParticipant {

    public func cellAccessibilityLabel() -> String {
        "\(displayName), \(cellAccessibilityAudioString()), \(cellAccessibilityVideoString())"
    }
    
    private func cellAccessibilityVideoString() -> String {
        switch videoMuteState {
        case .muted:
            dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_video_disabled")
        case .unmuted:
            dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_video_enabled")
        }
    }
    
    private func cellAccessibilityAudioString() -> String {
        switch audioMuteState {
        case .muted:
            dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_audio_disabled")
        case .unmuted:
            dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_audio_enabled")
        }
    }
}
