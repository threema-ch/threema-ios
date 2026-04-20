protocol AudioSessionManagerProtocol {
    var session: AVAudioSession { get }
    var prevAudioSessionCategory: AVAudioSession.Category? { get }

    func setupForPlayback() throws
    func setupForRecording() throws
    func adaptToProximityState()
    func setAmbientAudioActive(_ isActive: Bool)
}

extension AudioSessionManagerProtocol where Self == NullAudioSessionManager {
    static var null: Self { NullAudioSessionManager() }
}

struct NullAudioSessionManager: AudioSessionManagerProtocol {
    var session: AVAudioSession { .init() }
    var prevAudioSessionCategory: AVAudioSession.Category? { nil }

    func setupForPlayback() throws { /* no-op */ }
    func setupForRecording() throws { /* no-op */ }
    func adaptToProximityState() { /* no-op */ }
    func setAmbientAudioActive(_ isActive: Bool) { /* no-op */ }
}
