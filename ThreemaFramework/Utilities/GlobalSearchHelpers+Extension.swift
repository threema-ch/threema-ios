import Foundation
import ThreemaMacros

extension GlobalSearchConversationScope {
    public var title: String {
        switch self {
        case .all:
            #localize("all")
        case .oneToOne:
            #localize("one_to_one_chat")
        case .groups:
            #localize("groups")
        case .archived:
            #localize("archived_title")
        }
    }
}

extension GlobalSearchMessageToken {
    public var title: String {
        switch self {
        case .star:
            #localize("conversations_global_search_token_starred")
            
        case .text:
            #localize("conversations_global_search_token_text")
            
        case .caption:
            #localize("conversations_global_search_token_captions")
            
        case .poll:
            #localize("conversations_global_search_token_polls")
            
        case .location:
            #localize("conversations_global_search_token_locations")
        }
    }
    
    public var icon: UIImage? {
        switch self {
        case .star:
            UIImage(systemName: "star")
            
        case .text:
            UIImage(systemName: "text.alignleft")
            
        case .caption:
            UIImage(systemName: "text.below.photo")

        case .poll:
            UIImage(systemName: "chart.pie")

        case .location:
            UIImage(systemName: "mappin.and.ellipse")
        }
    }
    
    public var searchToken: UISearchToken {
        let token = UISearchToken(icon: icon, text: title)
        token.representedObject = self
        return token
    }
}
