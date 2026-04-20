extension RTCPeerConnectionState: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .new:
            return "NEW"
        case .connecting:
            return "CONNECTING"
        case .connected:
            return "CONNECTED"
        case .disconnected:
            return "DISCONNECTED"
        case .failed:
            return "FAILED"
        case .closed:
            return "CLOSED"
        @unknown default:
            return "UNKNOWN"
        }
    }
}
