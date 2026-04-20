import WebRTC

extension RTCCallbackLogger {
    
    /// IOS-4113, SE-297
    /// Filters know error messages from WebRTC logs, so the log is not spammed with them.
    /// - Parameter message: Message to check for occurrences.
    /// - Returns: Message if know logs did not occur, `nil` otherwise.
    static func trimMessage(message: String) -> String? {
        if message.contains("Failed to demux RTP packet") ||
            message
            .contains(
                "Another unsignalled ssrc packet arrived shortly after the creation of an unsignalled ssrc stream"
            ) {
            return nil
        }
        
        return message.trimmingCharacters(in: .newlines)
    }
}
