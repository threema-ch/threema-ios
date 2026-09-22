import Foundation

/// Holds the backup string captured from a restore deep-link (`threema://…backup=…`), set by
/// `URLHandler` and read by the Objective-C restore flow (`RestoreIdentityViewController`).
final class RestoreDataURLProvider: NSObject {
    @objc static var urlString: String?

    override private init() { }
}
