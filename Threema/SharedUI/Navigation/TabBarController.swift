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

import Coordinator
import Foundation
import ThreemaMacros

@objc final class TabBarController: UITabBarController, UITabBarControllerDelegate {
    
    public enum TabBarItem: Int, CaseIterable {
        case contacts
        case conversations
        case profile
        case settings
        
        var title: String {
            switch self {
            case .contacts:
                #localize("contacts")
            case .conversations:
                #localize("chats_title")
            case .profile:
                #localize("myIdentity")
            case .settings:
                #localize("settings")
            }
        }
        
        private var tabBarSymbol: UIImage? {
            switch self {
            case .contacts:
                UIImage(systemName: "person.2.fill")
            case .conversations:
                UIImage(systemName: "bubble.left.and.bubble.right.fill")
            case .profile:
                UIImage(systemName: "person.circle.fill")
            case .settings:
                UIImage(systemName: "gear")
            }
        }
        
        public var sideBarSymbol: UIImage? {
            switch self {
            case .contacts:
                UIImage(systemName: "person.2")
            case .conversations:
                UIImage(systemName: "bubble.left.and.bubble.right")
            case .profile:
                UIImage(systemName: "person")
            case .settings:
                UIImage(systemName: "gear")
            }
        }
        
        public var uiTabBarItem: UITabBarItem {
            UITabBarItem(title: title, image: tabBarSymbol, tag: rawValue)
        }
        
        public init(_ destination: Destination.AppDestination) {
            switch destination {
            case .contacts:
                self = .contacts
            case .conversations:
                self = .conversations
            case .profile:
                self = .profile
            case .settings:
                self = .settings
            }
        }
    }
    
    // MARK: - Coordinator
    
    weak var coordinator: AppCoordinator?
    
    // MARK: - Lifecycle
    
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
        delegate = self
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Delegate
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let tab = TabBarItem(rawValue: item.tag) else {
            assertionFailure("Selected tab has no matching tab item case.")
            return
        }
        
        coordinator?.swichtTab(to: tab)
    }
}
