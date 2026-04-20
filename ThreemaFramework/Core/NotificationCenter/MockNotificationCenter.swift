#if DEBUG
    import Foundation
    import ObjectiveC

    extension NotificationCenterProtocol where Self == MockNotificationCenter {
        public static var mock: Self { Self() }
    }

    public final class MockNotificationCenter: NotificationCenterProtocol {
        public init() { /* no-op */ }

        public var observers: [Observer] = []
        public var posted: [Notification] = []

        public func addObserver(
            forName name: NSNotification.Name?,
            object obj: Any?,
            queue: OperationQueue?,
            using block: @escaping @Sendable (Notification) -> Void
        ) -> any NSObjectProtocol {
            let observer = Observer(name: name, object: obj, block: block)
            observers.append(observer)
            return observer
        }
    
        public func removeObserver(_ observer: Any) {
            observers.removeAll { savedObserver in
                (observer as? Observer)?.id == savedObserver.id
            }
        }
    
        public func post(name aName: NSNotification.Name, object anObject: Any?) {
            post(name: aName, object: anObject, userInfo: nil)
        }
    
        public func post(
            name aName: NSNotification.Name,
            object anObject: Any?,
            userInfo aUserInfo: [AnyHashable: Any]?
        ) {
            let notification = Notification(name: aName, object: anObject, userInfo: aUserInfo)
            posted.append(notification)
            for observer in observers {
                var matchedName = true
                if let name = observer.name {
                    matchedName = aName == name
                }
                var matchedObject = true
                if let object = observer.object {
                    if let anObject {
                        matchedObject = haveSameIdentity(object, anObject)
                    }
                    else {
                        matchedObject = false
                    }
                }
                if matchedName, matchedObject {
                    observer.block(notification)
                }
            }
        }

        private func haveSameIdentity(_ lhs: Any, _ rhs: Any) -> Bool {
            guard
                let lhsObj = lhs as AnyObject?,
                let rhsObj = rhs as AnyObject?
            else {
                return false
            }
            return lhsObj === rhsObj
        }

        public final class Observer: NSObject {
            public let id = UUID()
            public let name: NSNotification.Name?
            public let object: Any?
            public let block: @Sendable (Notification) -> Void

            init(name: NSNotification.Name?, object: Any?, block: @escaping @Sendable (Notification) -> Void) {
                self.name = name
                self.object = object
                self.block = block
            }
        }
    }

#endif
