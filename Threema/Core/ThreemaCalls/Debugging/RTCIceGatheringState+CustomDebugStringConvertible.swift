extension RTCIceGatheringState: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .new:
            return "NEW"
        case .gathering:
            return "GATHERING"
        case .complete:
            return "COMPLETE"
        @unknown default:
            return "UNKNOWN"
        }
    }
}
