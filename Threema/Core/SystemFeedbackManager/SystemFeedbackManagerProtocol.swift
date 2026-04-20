protocol SystemFeedbackManagerProtocol {
    func playSuccessSound()
    func vibrate()
}

extension SystemFeedbackManagerProtocol where Self == NullSystemFeedbackManager {
    static var null: Self { NullSystemFeedbackManager() }
}

struct NullSystemFeedbackManager: SystemFeedbackManagerProtocol {
    func playSuccessSound() { /* no-op */ }
    func vibrate() { /* no-op */ }
}
