import ThreemaFramework
import ThreemaMacros

public struct CallActionFactory: Factory {
    
    private let title: String
    private let action: () -> Void
    
    init(
        title: String = "",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
    }
    
    public func make() -> UIContextualAction {
        let callAction = UIContextualAction(
            style: .normal,
            title: title,
        ) { _, _, handler in
            action()
            handler(true)
        }
        
        callAction.image = UIImage(resource: .threemaPhoneFill)
        callAction.backgroundColor = .systemGray
        
        return callAction
    }
}

extension CallActionFactory {
    public static func make(for group: Group) -> UIContextualAction {
        CallActionFactory {
            Task {
                await GlobalGroupCallManagerSingleton.shared.startGroupCall(
                    in: group,
                    intent: .createOrJoin
                )
            }
        }.make()
    }
    
    public static func make(for contact: Contact) -> UIContextualAction {
        CallActionFactory(title: #localize("call")) {
            VoIPCallStateManager.shared.startCall(callee: contact.identity.rawValue)
        }.make()
    }
}
