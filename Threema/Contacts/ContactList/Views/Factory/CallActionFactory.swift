//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
            let action = VoIPCallUserAction(
                action: .call,
                contactIdentity: contact.identity.rawValue,
                callID: nil,
                completion: nil
            )
            VoIPCallStateManager.shared.processUserAction(action)
        }.make()
    }
}
