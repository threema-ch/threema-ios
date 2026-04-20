import Foundation
import ObjectiveC

public protocol NotificationCenterProtocol {
    func addObserver(
        forName name: NSNotification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping @Sendable (Notification) -> Void
    ) -> any NSObjectProtocol

    func removeObserver(_ observer: Any)

    func post(name aName: NSNotification.Name, object anObject: Any?)

    func post(name aName: NSNotification.Name, object anObject: Any?, userInfo aUserInfo: [AnyHashable: Any]?)
}

// MARK: - NotificationCenter + NotificationCenterProtocol

extension NotificationCenter: NotificationCenterProtocol { }
