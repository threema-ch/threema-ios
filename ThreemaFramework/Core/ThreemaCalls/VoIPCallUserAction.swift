//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

@objc public class VoIPCallUserAction: NSObject {
    
    @objc public enum Action: Int {
        case call
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
        case hideCallScreen
    }
        
    @objc public let action: Action
    @objc public let contactIdentity: String
    @objc public let completion: (() -> Void)?
    @objc public let callID: VoIPCallID?
    
    @objc public init(action: Action, contactIdentity: String, callID: VoIPCallID?, completion: (() -> Void)?) {
        self.action = action
        self.contactIdentity = contactIdentity
        self.completion = completion
        self.callID = callID
        super.init()
    }
}
