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

import SwiftUI
import ThreemaFramework

// TODO: (IOS-5212) Remove all the views in this file

/// Temproary view allowing us to disable the new navigation setting
struct TempTabView: View {
    @State var newNavigationEnabled = UserSettings.shared().newNavigationEnabled

    let tab: TabBarController.TabBarItem
    
    var body: some View {
        VStack {
            Text(tab.title)
                .font(.largeTitle)
            Toggle(isOn: $newNavigationEnabled) {
                Text(verbatim: "Enable new Navigation")
            }
        }
        .padding()
        .onChange(of: newNavigationEnabled) { newValue in
            UserSettings.shared().newNavigationEnabled = newValue
            exit(1)
        }
    }
}
