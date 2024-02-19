//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
import ThreemaFramework

protocol MainTabViewRepresentable: View {
    var title: String { get }
    var symbol: UIImage? { get }
}

extension MainTabViewRepresentable {
    func makeViewController(_ appContainer: AppContainer) -> UIViewController {
        UIHostingController(
            rootView: inject(appContainer)
        ).then {
            $0.title = title
            $0.tabBarItem.title = title
            $0.tabBarItem.image = symbol
        }
    }
}
