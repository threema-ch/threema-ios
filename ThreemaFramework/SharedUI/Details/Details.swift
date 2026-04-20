/// When we remove `objc` move this into the `Details` name space and remove `Int`
@objc public enum DetailsDisplayStyle: Int {
    case `default`
    case preview
}

/// Delegate for details
///
/// When we remove `objc` check if we can move this into the `Details` name space
@objc public protocol DetailsDelegate: AnyObject {
    /// Called when the details view controller did disappear
    func detailsDidDisappear()
    
    /// Show a chat search in the delegate
    func showChatSearch(forStarred: Bool)
    
    /// Called before the detail view deletes messages
    /// - Parameter objectIDs: Object IDs of messages that will be deleted
    func willDeleteMessages(with objectIDs: [NSManagedObjectID])
    
    /// Called before the detail view will delete all messages in this conversation
    func willDeleteAllMessages()
}

public enum Details {

    public struct Action: Hashable {
        public typealias Action = (UIView) -> Void

        public let title: String

        public let imageName: String?

        public let destructive: Bool

        public let disabled: Bool

        public let run: Action

        public init(
            title: String,
            imageName: String? = nil,
            destructive: Bool = false,
            disabled: Bool = false,
            action: @escaping Action
        ) {
            self.title = title
            self.imageName = imageName
            self.destructive = destructive
            self.disabled = disabled
            self.run = action
        }
        
        // Equatable
        public static func == (lhs: Details.Action, rhs: Details.Action) -> Bool {
            lhs.title == rhs.title
                && lhs.imageName == rhs.imageName
                && lhs.destructive == rhs.destructive
        }
        
        // Hashable
        public func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(imageName)
            hasher.combine(destructive)
        }
    }
    
    public struct BooleanAction: Hashable {
        public typealias BoolProvider = () -> Bool
        public typealias Action = (Bool) -> Void

        public let title: String
        public let currentBool: BoolProvider
        
        public let destructive: Bool
        public let disabled: Bool
        
        public let run: Action
        
        public init(
            title: String,
            destructive: Bool = false,
            disabled: Bool = false,
            boolProvider: @escaping BoolProvider,
            action: @escaping Action
        ) {
            self.title = title
            self.destructive = destructive
            self.disabled = disabled
            self.currentBool = boolProvider
            self.run = action
        }
        
        // Equatable
        public static func == (lhs: Details.BooleanAction, rhs: Details.BooleanAction) -> Bool {
            lhs.title == rhs.title
                && lhs.destructive == rhs.destructive
        }
        
        // Hashable
        public func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(destructive)
        }
    }
}
