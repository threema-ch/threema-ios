/// Why a claim could not be granted.
public enum AudioSessionError: Error, Equatable, Sendable {
    /// A call owns the session and the requested kind cannot be subordinated to it.
    case busyWithCall
}
