/// Who activates the session a profile is applied to.
public enum AudioSessionActivation: Sendable, Equatable {

    /// Someone else calls `setActive(true)`, e.g. under CallKit.
    case external

    /// The driver activates the session itself, as part of applying the profile.
    case driverOwned
}
