import Foundation
import UIKit

/// Destinations to be shown from anywhere in the app.
/// - Important: Destinations that are scoped to a `Coordinator` should be referenced in the respective implementation.
public enum Destination: Equatable {
    case app(AppDestination)
    
    /// Each case represents one of our tabs
    public enum AppDestination: Equatable {
        case contacts
        case conversations
        case profile
        case settings
        
        public enum ContactsDestination: Equatable {
            case todo
        }
        
        public enum ConversationsDestination: Equatable {
            case todo
        }
        
        public enum ProfileDestination: Equatable {
            case todo
        }
        
        public enum SettingsDestination: Equatable {
            case todo
        }
    }
}

/// Style describing how a view controller should be shown
public indirect enum CoordinatorNavigationStyle {
    case show
    case modal(style: UIModalPresentationStyle = .automatic, transition: UIModalTransitionStyle = .coverVertical)
    case passcode(style: CoordinatorNavigationStyle)
}
