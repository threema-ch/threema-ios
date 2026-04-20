import Foundation

/// Indicates from where a function call is triggered:
///     - local -> modifications by the user
///     - remote -> modifications by incoming CSP messages
///     - sync -> modifications by incoming MSP messages
@objc public enum SourceCaller: Int {
    case local, remote, sync
}
