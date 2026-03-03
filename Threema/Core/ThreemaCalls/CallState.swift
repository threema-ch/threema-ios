//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import ThreemaMacros

@objc public enum CallState: Int, RawRepresentable, Equatable {
    case idle
    case sendOffer
    case receivedOffer
    case outgoingRinging
    case incomingRinging
    case sendAnswer
    case receivedAnswer
    case initializing
    case calling
    case reconnecting
    case ended
    case remoteEnded
    case rejected
    case rejectedBusy
    case rejectedTimeout
    case rejectedDisabled
    case rejectedOffHours
    case rejectedUnknown
    case microphoneDisabled
        
    var active: Bool {
        self != .idle
    }
        
    /// Return the string of the current state for the debug log
    /// - Returns: String of the current state
    func description() -> String {
        switch self {
        case .idle: "IDLE"
        case .sendOffer: "SENDOFFER"
        case .receivedOffer: "RECEIVEDOFFER"
        case .outgoingRinging: "RINGING"
        case .incomingRinging: "RINGING"
        case .sendAnswer: "SENDANSWER"
        case .receivedAnswer: "RECEIVEDANSWER"
        case .initializing: "INITIALIZING"
        case .calling: "CALLING"
        case .reconnecting: "RECONNECTING"
        case .ended: "ENDED"
        case .remoteEnded: "REMOTEENDED"
        case .rejected: "REJECTED"
        case .rejectedBusy: "REJECTEDBUSY"
        case .rejectedTimeout: "REJECTEDTIMEOUT"
        case .rejectedDisabled: "REJECTEDDISABLED"
        case .rejectedOffHours: "REJECTEDOFFHOURS"
        case .rejectedUnknown: "REJECTEDUNKNOWN"
        case .microphoneDisabled: "MICROPHONEDISABLED"
        }
    }
        
    /// Get the localized string for the current state
    /// - Returns: Current localized call state string
    func localizedString() -> String {
        switch self {
        case .idle: #localize("call_status_idle")
        case .sendOffer: #localize("call_status_wait_ringing")
        case .receivedOffer: #localize("call_status_wait_ringing")
        case .outgoingRinging: #localize("call_status_ringing")
        case .incomingRinging: String.localizedStringWithFormat(
                #localize("call_status_incom_ringing"),
                TargetManager.localizedAppName
            )
        case .sendAnswer: #localize("call_status_ringing")
        case .receivedAnswer: #localize("call_status_ringing")
        case .initializing: #localize("call_status_initializing")
        case .calling: #localize("call_status_calling")
        case .reconnecting: #localize("call_status_reconnecting")
        case .ended: #localize("call_end")
        case .remoteEnded: #localize("call_end")
        case .rejected: #localize("call_rejected")
        case .rejectedBusy: #localize("call_rejected_busy")
        case .rejectedTimeout: #localize("call_rejected_timeout")
        case .rejectedDisabled: String.localizedStringWithFormat(
                #localize("call_rejected_disabled"),
                TargetManager.localizedAppName
            )
        case .rejectedOffHours: #localize("call_rejected")
        case .rejectedUnknown: #localize("call_rejected")
        case .microphoneDisabled: #localize("call_mic_access")
        }
    }
}
