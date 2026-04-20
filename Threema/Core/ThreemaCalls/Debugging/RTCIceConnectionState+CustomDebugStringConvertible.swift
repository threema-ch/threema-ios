extension RTCIceConnectionState: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .new:
            return "NEW"
        case .checking:
            return "CHECKING"
        case .connected:
            return "CONNECTED"
        case .completed:
            return "COMPLETED"
        case .failed:
            return "FAILED"
        case .disconnected:
            return "DISCONNECTED"
        case .closed:
            return "CLOSED"
        case .count:
            return "COUNT"
        @unknown default:
            return "UNKNOWN"
        }
    }
}
