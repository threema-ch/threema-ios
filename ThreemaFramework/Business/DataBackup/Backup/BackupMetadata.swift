/// What a single data backup holds, and — once it exists — when it was made and how big it is.
///
/// Serves both directions of that: the categories of the backup that is about to be made, and the record of the one
/// that was.
public struct BackupMetadata: Sendable, Codable, Equatable {
    /// Date and time at which the backup was created.
    public var date: Date

    /// Total size of the backup on disk, in bytes.
    /// Stored as a `UInt64`, so the representable maximum (~18.4 billion GB) is far beyond any realistic backup size.
    public var size: UInt64

    /// Whether the backup includes chat messages.
    public var includesMessages: Bool

    /// Whether the backup includes media (photos, videos, audio, documents, etc.).
    public var includesMedia: Bool

    /// Initializer with default values
    public init(date: Date = .now, size: UInt64 = 0, includesMessages: Bool = true, includesMedia: Bool = true) {
        self.date = date
        self.size = size
        self.includesMessages = includesMessages
        self.includesMedia = includesMedia
    }
}
