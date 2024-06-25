//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import Foundation
import ThreemaFramework

@objc class ContactListNavigationViewController: ThemedNavigationController {
    init() {
        super.init(
            navigationBarClass: StatusNavigationBar.self,
            toolbarClass: nil
        )
        let title = "contacts".localized
        pushViewController(
            ContactListViewController().then {
                $0.title = title
                $0.navigationItem.title = title
            },
            animated: false
        )
        navigationBar.prefersLargeTitles = false
        tabBarItem.image = UIImage(systemName: "person.2.fill")
        tabBarItem.title = title
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
