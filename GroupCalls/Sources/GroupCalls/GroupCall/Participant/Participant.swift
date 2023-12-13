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
import ThreemaEssentials

class Participant: ParticipantDescription {
    let participantID: ParticipantID

    var mirrorRenderer: Bool {
        false
    }
    
    var type: String {
        fatalError("Must override")
    }

    var localCameraPosition: CameraPosition = .front
    
    init(participantID: ParticipantID) {
        self.participantID = participantID
    }
    
    // TODO: (IOS-4081) Replace NSObject with actual valid object
    func subscribeCamera(renderer: NSObject, width: Int, height: Int, fps: Int = 30) {
        fatalError("Must override")
    }
    
    func unsubscribeCamera() {
        fatalError("Must override")
    }
    
    static func == (lhs: Participant, rhs: Participant) -> Bool {
        lhs.participantID == rhs.participantID
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(participantID)
    }
}
