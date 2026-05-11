public enum TypingIndicatorConfig {
    /// How often to resend the typing indicator to keep it active (seconds)
    public static let resendInterval = TimeInterval(50)

    /// How long to wait before considering typing paused (seconds)
    public static let typingPauseInterval = TimeInterval(15)

    /// How long before a stale typing indicator is reset (seconds)
    public static let timeoutInterval = TimeInterval(60)

    /// How often to check for stale typing indicators (half of timeout)
    public static let resetCheckInterval: TimeInterval = timeoutInterval / 2

    /// Label for the reset timer's dispatch queue
    public static let resetQueueLabel = "ch.threema.typingIndicatorResetQueue"
}
