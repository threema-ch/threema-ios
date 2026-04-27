import Coordinator
import Foundation
import ThreemaMacros

public enum ThreemaTab: Int, CaseIterable {
    case contacts
    case conversations
    case profile
    case settings
    
    var title: String {
        switch self {
        case .contacts:
            #localize("contacts")
        case .conversations:
            #localize("chats_title")
        case .profile:
            #localize("myIdentity")
        case .settings:
            #localize("settings")
        }
    }
    
    private var image: UIImage? {
        switch self {
        case .contacts:
            UIImage(systemName: "person.2.fill")
        case .conversations:
            UIImage(systemName: "bubble.left.and.bubble.right.fill")
        case .profile:
            UIImage(systemName: "person.circle.fill")
        case .settings:
            UIImage(systemName: "gear")
        }
    }
    
    public var tabBarItem: UITabBarItem {
        UITabBarItem(title: title, image: image, tag: rawValue)
    }
    
    public init(_ destination: Destination.AppDestination) {
        switch destination {
        case .contacts:
            self = .contacts
        case .conversations:
            self = .conversations
        case .profile:
            self = .profile
        case .settings:
            self = .settings
        }
    }
}

@objc public final class ThreemaTabBarController: UITabBarController {
    
    // MARK: - Public properties
    
    public var selectedThreemaTab: ThreemaTab {
        ThreemaTab(rawValue: selectedIndex) ?? .conversations
    }
    
    public func navigationController(
        for tab: ThreemaTab
    ) -> UINavigationController? {
        guard let viewControllers, viewControllers.count > tab.rawValue else {
            return nil
        }
        
        return viewControllers[tab.rawValue] as? UINavigationController
    }
}
