import ThreemaFramework
import ThreemaMacros

struct ContactListSwipeActionProvider {
    
    private let businessInjector: any BusinessInjectorProtocol
    
    init(businessInjector: any BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
    }
    
    func makeLeadingSwipeActions(for contact: Contact) -> [UIContextualAction] {
        var actions: [UIContextualAction] = []
        
        let messageAction = MessageActionFactory.make(for: contact)
        actions.append(messageAction)
        
        if businessInjector.settingsStore.enableThreemaCall,
           contact.supportsCalls {
            let callAction = CallActionFactory.make(for: contact)
            actions.append(callAction)
        }
        
        return actions
    }
    
    func makeLeadingSwipeActions(
        for group: ThreemaFramework.Group,
        conversation: ConversationEntity
    ) -> [UIContextualAction] {
        var actions: [UIContextualAction] = []
        
        let messageAction = MessageActionFactory.make(for: conversation)
        actions.append(messageAction)
        
        if businessInjector.settingsStore.enableThreemaGroupCalls {
            let groupCallAction = CallActionFactory.make(for: group)
            actions.append(groupCallAction)
        }
        
        return actions
    }
    
    func makeTrailingDeleteConfiguration(
        title: String,
        action: @escaping () -> Void
    ) -> UISwipeActionsConfiguration {
        let deleteAction = DeleteActionFactory(title: title, action: action).make()
        let config = UISwipeActionsConfiguration(actions: [deleteAction])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
}
