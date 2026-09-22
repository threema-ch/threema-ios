import Coordinator
import Foundation
import ThreemaMacros

enum ThreemaTab: Int, CaseIterable {
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
    
    var tabBarItem: UITabBarItem {
        UITabBarItem(title: title, image: image, tag: rawValue)
    }
    
    init(_ destination: Destination.AppDestination) {
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

final class ThreemaTabBarController: UITabBarController {
    
    // MARK: - Properties
    
    var selectedThreemaTab: ThreemaTab {
        ThreemaTab(rawValue: selectedIndex) ?? .conversations
    }

    func navigationController(
        for tab: ThreemaTab
    ) -> UINavigationController? {
        guard let viewControllers, viewControllers.count > tab.rawValue else {
            return nil
        }
        
        return viewControllers[tab.rawValue] as? UINavigationController
    }
}
