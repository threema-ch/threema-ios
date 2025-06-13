//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import SwiftUI
import SwiftUIIntrospect
@_spi(Advanced) import SwiftUIIntrospect
import ThreemaFramework

protocol MainTabViewRepresentable: View {
    var title: String { get }
    var symbol: UIImage? { get }
    var tag: Int { get }
    var screenshotIdentifier: String { get }
}

extension MainTabViewRepresentable {
    func makeViewController(_ appContainer: AppContainer) -> UIViewController {
        UIHostingController(
            rootView: inject(appContainer).registerPopToRoot(with: tag)
        ).then {
            $0.title = title
            $0.tabBarItem.title = title
            $0.tabBarItem.image = symbol
            $0.tabBarItem.tag = tag
            $0.tabBarItem.accessibilityIdentifier = screenshotIdentifier
        }
    }
}

extension View {
    func registerPopToRoot(with tag: Int) -> some View {
        introspect(.navigationView(style: .stack), on: .iOS(.v15...), customize: { navigationController in
            NotificationCenter.default
                .addObserver(
                    forName: NSNotification.Name("popToRoot-\(tag)"),
                    object: nil,
                    queue: nil
                ) { [weak navigationController] notification in
                    if let tag = notification.object as? Int,
                       let mainTabBarController = AppDelegate.getMainTabBarController() as? MainTabBarController,
                       mainTabBarController.selectedIndex == tag {
                        navigationController?.popToRootViewController(animated: true)
                    }
                }
        })
    }
}
