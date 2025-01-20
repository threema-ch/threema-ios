//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import UIKit

class ContactListNavigationItem: UINavigationItem {
    private weak var delegate: ContactListActionDelegate?
    private lazy var contactAddMenu = UIMenu(delegate?.add ?? { _ in })
    private lazy var contactListFilter = ScrollableMenuView(delegate?.filterChanged ?? { _ in })
    #if THREEMA_WORK
        private lazy var switchWorkContacts = WorkButtonView(delegate?.didToggleWorkContacts ?? { _ in })
        var shouldShowWorkButton = true {
            willSet {
                setLeftBarButton(newValue ? UIBarButtonItem(customView: switchWorkContacts.view) : nil, animated: false)
            }
        }
    #endif
    
    init(delegate: ContactListActionDelegate? = nil) {
        self.delegate = delegate
        super.init(title: "")

        titleView = contactListFilter.view
        rightBarButtonItem = UIBarButtonItem(systemItem: .add, menu: contactAddMenu)
        #if THREEMA_WORK
            leftBarButtonItem = UIBarButtonItem(customView: switchWorkContacts.view)
        #endif
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
