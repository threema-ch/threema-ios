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
    
    // MARK: - Properties

    private weak var delegate: ContactListActionDelegate?
    
    var shouldShowWorkButton = true {
        willSet {
            leftBarButtonItem = newValue ? toggleWorkItem : nil
        }
    }
    
    private var workContactsFilterActive = false
    
    // MARK: - Subviews
    
    private lazy var addMenuItem = UIBarButtonItem(systemItem: .add, menu: UIMenu(delegate?.add ?? { _ in }))
    
    private lazy var filterItem = ScrollableMenuView(delegate?.filterChanged ?? { _ in })
    
    private lazy var toggleWorkItem: UIBarButtonItem = {
        let image = UIImage(resource: .threemaCaseFillCircle)
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(didToggleWorkContacts))
        
        return item
    }()
    
    // MARK: - Lifecycle

    init(delegate: ContactListActionDelegate? = nil) {
        self.delegate = delegate
        super.init(title: "")

        configureNavigationBarItems()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private functions

    private func configureNavigationBarItems() {
        titleView = filterItem.view
        rightBarButtonItem = addMenuItem
        
        if TargetManager.isWork {
            leftBarButtonItem = toggleWorkItem
        }
    }
    
    @objc private func didToggleWorkContacts() {
        guard let delegate else {
            return
        }
        
        workContactsFilterActive.toggle()
        
        toggleWorkItem
            .image = UIImage(resource: workContactsFilterActive ? .threemaCaseCircleFill : .threemaCaseFillCircle)
        
        delegate.didToggleWorkContacts(workContactsFilterActive)
    }
}
