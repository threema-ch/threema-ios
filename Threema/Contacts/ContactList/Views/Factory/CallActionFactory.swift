import ThreemaFramework
import ThreemaMacros

struct CallActionFactory: Factory {
    
    private let title: String
    private let action: () -> Void
    
    init(
        title: String = "",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
    }
    
    func make() -> UIContextualAction {
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
    static func make(for group: Group) -> UIContextualAction {
        CallActionFactory(title: #localize("call")) {
            Task { @MainActor in
                CallProvider.shared.startGroupCall(
                    in: group,
                    intent: .createOrJoin
                )
            }
        }.make()
    }
    
    static func make(for contact: Contact) -> UIContextualAction {
        CallActionFactory(title: #localize("call")) {
            Task { @MainActor in
                CallProvider.shared.startOutgoingCall(
                    with: contact.identity.rawValue
                )
            }
        }.make()
    }
}
