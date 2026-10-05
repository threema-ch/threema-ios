import ThreemaMacros

@objc public enum CallState: Int, RawRepresentable, Equatable, CustomStringConvertible {
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
    case rejectedTimeout
    case rejectedUnknown
    case microphoneDisabled
        
    var active: Bool {
        self != .idle
    }
    
    /// Does not keep the app running in the background, unlike an answered call
    var isUnansweredIncoming: Bool {
        self == .receivedOffer || self == .incomingRinging
    }

    public var description: String {
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
        case .rejectedTimeout: "REJECTEDTIMEOUT"
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
        case .rejectedTimeout: #localize("call_rejected_timeout")
        case .rejectedUnknown: #localize("call_rejected")
        case .microphoneDisabled: #localize("call_mic_access")
        }
    }
}
