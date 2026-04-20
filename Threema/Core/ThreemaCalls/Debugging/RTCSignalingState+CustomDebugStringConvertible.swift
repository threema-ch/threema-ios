extension RTCSignalingState: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .stable:
            return "STABLE"
        case .haveLocalOffer:
            return "HAVE_LOCAL_OFFER"
        case .haveLocalPrAnswer:
            return "HAVE_LOCAL_PR_ANSWER"
        case .haveRemoteOffer:
            return "HAVE_REMOTE_OFFER"
        case .haveRemotePrAnswer:
            return "HAVE_REMOTE_PR_ANSWER"
        case .closed:
            return "CLOSED"
        @unknown default:
            return "UNKNOWN"
        }
    }
}
