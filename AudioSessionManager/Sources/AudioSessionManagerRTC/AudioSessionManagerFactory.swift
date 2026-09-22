import AudioSessionManager

/// Builds the one `AudioSessionManager` the app runs on.
public enum AudioSessionManagerFactory {

    /// There is no variant without the call driver. One manager serves every client — calls, recording,
    /// playback, ambient — because the session it owns is a process singleton.
    ///
    /// This is the only way an app target can obtain a manager: both of `AudioSessionManager`'s
    /// initialisers are `package`, and `RTCAudioSessionDriver` is internal. That is what makes "one
    /// manager per process" structural.
    public static func make() -> any AudioSessionManagerProtocol {
        AudioSessionManager(callDriver: RTCAudioSessionDriver())
    }
}
