import ThreemaMacros

public struct DeleteActionFactory: Factory {
    
    private let title: String
    private let action: () -> Void
    
    init(
        title: String = #localize("delete"),
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
    }
    
    public func make() -> UIContextualAction {
        let deleteAction = UIContextualAction(
            style: .destructive,
            title: title
        ) { _, _, handler in
            action()
            handler(true)
        }
        
        deleteAction.image = UIImage(systemName: "trash.fill")
        
        return deleteAction
    }
}
