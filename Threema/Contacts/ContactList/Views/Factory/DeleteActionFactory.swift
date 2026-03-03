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
