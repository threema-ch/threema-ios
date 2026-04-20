extension RTCDataChannelState: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .connecting:
            return "CONNECTING"
        case .open:
            return "OPEN"
        case .closing:
            return "CLOSING"
        case .closed:
            return "CLOSED"
        @unknown default:
            return "UNKNOWN"
        }
    }
}
