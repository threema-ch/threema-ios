enum SingleDetails {
    
    enum State {
        case contactDetails(contact: ContactEntity)
        case conversationDetails(contact: ContactEntity, conversation: ConversationEntity)
    }
    
    enum Section {
        case contentActions
        case contactInfo
        case groups
        case notifications
        case shareAction
        case contactActions
        case privacySettings
        case wallpaper
        case fsActions
        case debugInfo
    }
    
    enum Row: Hashable {
        
        // General
        case action(_ action: Details.Action)
        case booleanAction(_ action: Details.BooleanAction)
        case value(label: String, value: String)
        
        // Contact info
        case verificationLevel(contact: ContactEntity)
        case publicKey
        
        case linkedContact(_ linkedContactManager: LinkedContactManager)
        
        // Groups
        case group(_ group: Group)
        
        // Notifications
        case doNotDisturb(action: Details.Action, contact: ContactEntity)
        
        // Privacy Settings
        case privacySettings(action: Details.Action, contact: ContactEntity)
        
        // Wallpaper
        case wallpaper(action: Details.Action, isDefault: Bool)
        
        // Debug
        case coreDataDebugInfo(contact: ContactEntity)
        case fsDebugInfo(sessionInfo: String)
    }
}
