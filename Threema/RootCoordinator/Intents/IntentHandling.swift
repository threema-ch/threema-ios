import UIKit

/// Receiver that the proxy forwards intent/URL/shortcut callbacks to. In production this is the
/// real ``IntentHandler``; in tests it can be any object conforming to this protocol.
@MainActor
protocol IntentHandling: AnyObject {
    @discardableResult
    func handle(userActivity: NSUserActivity) -> Bool
    
    @discardableResult
    func handle(openURL url: URL) -> Bool
    
    @discardableResult
    func handle(shortcutItem: UIApplicationShortcutItem) -> Bool
}
