import Foundation

protocol QuickActionUpdate {
    func reload()
    func hide()
    func popOverSourceView() -> UIView?
}

/// Description of a quick action
///
/// Use it to define quick actions in a `QuickActionsView`.
struct QuickAction {
    typealias ImageNameProvider = () -> String
    
    /// String of image available as asset
    let imageNameProvider: ImageNameProvider
    
    /// Title of action
    let title: String
    
    let accessibilityIdentifier: String
    
    /// Action performed when selected
    let action: (QuickActionUpdate) -> Void
    
    /// Create a quick action
    /// - Parameters:
    ///   - imageNameProvider: Provider for name of current SF Symbol to show
    ///   - title: Quick action title
    ///   - action: Action called when quick action is invoked
    ///   - accessibilityIdentifier: Identifier to find the button in UI tests
    init(
        imageNameProvider: @escaping ImageNameProvider,
        title: String,
        accessibilityIdentifier: String,
        action: @escaping (QuickActionUpdate) -> Void
    ) {
        self.imageNameProvider = imageNameProvider
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }
    
    /// Create a quick action with a fixed image
    /// - Parameters:
    ///   - imageName: Name of SF Symbol to show
    ///   - title: Quick action title
    ///   - action: Action called when quick action is invoked
    ///   - accessibilityIdentifier: Identifier to find the button in UI tests
    init(
        imageName: String,
        title: String,
        accessibilityIdentifier: String,
        action: @escaping (QuickActionUpdate) -> Void
    ) {
        self.init(
            imageNameProvider: { imageName },
            title: title,
            accessibilityIdentifier: accessibilityIdentifier,
            action: action
        )
    }
}

// MARK: - Hashable

extension QuickAction: Hashable {
    static func == (lhs: QuickAction, rhs: QuickAction) -> Bool {
        lhs.title == rhs.title
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }
}
