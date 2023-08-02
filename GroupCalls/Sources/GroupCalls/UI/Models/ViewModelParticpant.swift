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
    
    let id: ParticipantID
    let threemaID: ThreemaID
    
    let name: String
    let avatar: UIImage?
    let idColor: UIColor
    
    var audioMuteState: MuteState = .muted
    var videoMuteState: MuteState = .muted
    
    public init(remoteParticipant: RemoteParticipant, name: String?, avatar: UIImage?, idColor: UIColor) async {
        let threemaID = await remoteParticipant.getIdentity()!
        self.id = await remoteParticipant.getID()
        self.name = name ?? threemaID.id
        self.threemaID = threemaID
        self.avatar = avatar
        self.idColor = idColor
    }
    
    init(localParticipant: LocalParticipant, name: String?, avatar: UIImage?, idColor: UIColor) async {
        let threemaID = try! ThreemaID(id: localParticipant.identity)
        self.id = localParticipant.id
        self.name = name ?? threemaID.id
        self.threemaID = threemaID
        self.avatar = avatar
        self.idColor = idColor
        
        self.audioMuteState = GroupCallConfiguration.LocalInitialMuteState.audio.muteState()
        self.videoMuteState = GroupCallConfiguration.LocalInitialMuteState.video.muteState()
    }
}

// MARK: - Equatable

extension ViewModelParticipant: Equatable {
    public static func == (lhs: ViewModelParticipant, rhs: ViewModelParticipant) -> Bool {
        lhs.id == rhs.id && lhs.threemaID == rhs.threemaID && lhs.name == rhs.name && lhs.avatar == rhs.avatar && lhs
            .idColor == rhs.idColor && lhs.audioMuteState == rhs.audioMuteState && lhs.videoMuteState == rhs
            .videoMuteState
    }
}
