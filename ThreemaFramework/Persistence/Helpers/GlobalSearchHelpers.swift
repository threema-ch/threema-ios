import Foundation

public enum GlobalSearchConversationScope: Int {
    case all
    case oneToOne
    case groups
    case archived
}

public enum GlobalSearchMessageToken: Identifiable, CaseIterable {
    // Message markers
    case star
    
    // Message types
    case text
    case caption
    case poll
    case location
    
    public var id: Self {
        self
    }
}
