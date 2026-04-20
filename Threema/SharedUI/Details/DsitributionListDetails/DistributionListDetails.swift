import Foundation

/// When we ditch `objc` move this into the `DistributionListDetails` name space and remove `Int`
@objc enum DistributionListDetailsDisplayMode: Int {
    case `default`
    case conversation
}

enum DistributionListDetails {
    enum Section {
        case recipients
        case contentActions
        case destructiveDistributionListActions
        case wallpaperActions
    }
    
    enum Row: Hashable {
        // General
        case action(_ action: Details.Action)
        
        // Distribution List Recipients
        case contact(_ contact: Contact, isSelfMember: Bool = true)
        case unknownContact
        case recipientsAction(_ action: Details.Action)
        
        // Wallpaper
        case wallpaper(action: Details.Action, isDefault: Bool)
    }
}
