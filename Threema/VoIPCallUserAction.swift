//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

@objc class VoIPCallUserAction: NSObject {
    
    @objc enum Action: Int {
        case call
        case callWithVideo
        case accept
        case acceptCallKit
        case reject
        case rejectDisabled
        case rejectTimeout
        case rejectBusy
        case rejectUnknown
        case rejectOffHours
        case end
        case speakerOn
        case speakerOff
        case muteAudio
        case unmuteAudio
        case showCallScreen
        case hideCallScreen
    }
        
    @objc let action: Action
    @objc let contact: Contact
    @objc let completion: (() -> Void)?
    @objc let callId: VoIPCallId?
    
    @objc init(action: Action, contact: Contact, callId: VoIPCallId?, completion: (() -> Void)?) {
        self.action = action
        self.contact = contact
        self.completion = completion
        self.callId = callId
        super.init()
    }

}
