import Foundation

/// A client's registered intent.
public struct AudioSessionClaim: Sendable, Equatable {
    
    public let id: UUID

    /// What this was granted for, which is also its arbitration priority and its configuration.
    public let kind: AudioSessionClientKind

    // MARK: - Lifecycle

    // Marked as `package` due to making it available for testing.
    package init(id: UUID = UUID(), kind: AudioSessionClientKind) {
        self.id = id
        self.kind = kind
    }
}
