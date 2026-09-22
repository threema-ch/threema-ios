/// Restores a session that cannot be recovered by configuring it.
public protocol AudioSessionRecovering: Sendable {
    func requestAudioSessionReactivation() async
}
