/// Check if a conversation is potential spam
///
/// - Note: The detection needs Core Data access. Thus it is isolated to an actor to guarantee that it never runs on
///         the main queue.
public protocol SpamDetecting: Actor {
    func isPotentialSpam(conversationObjectID: NSManagedObjectID) async -> Bool
}
