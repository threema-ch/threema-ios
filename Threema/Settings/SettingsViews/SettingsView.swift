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
import ThreemaFramework

struct SettingsView: View {
    var settingsStore = BusinessInjector.ui.settingsStore as! SettingsStore
    @ObservedObject var settingsViewModel = SettingsViewModel()

    // MARK: - Body

    var body: some View {
        ThreemaNavigationView {
            ThreemaTableView {
                FeedbackDevSection()
                GeneralSection()
                DesktopSection()
                ConnectionSection()
                
                if TargetManager.isBusinessApp {
                    RateBusinessSection()
                }
                else {
                    ThreemaWorkAdvertisingSection()
                    InviteConsumerSection()
                }
                
                AboutSection()
            }
            .navigationDestination(for: AnyViewDestination.self)
            .navigationTitle(title)
        }
        .environmentObject(settingsViewModel)
        .environmentObject(settingsViewModel.navigator)
        .environmentObject(settingsStore)
        .onReceive(\.showNotificationSettings) { _ in
            settingsViewModel.navigator.navigate(
                NotificationSettingsView()
                    .environmentObject(settingsViewModel)
                    .environmentObject(settingsViewModel.navigator)
                    .environmentObject(settingsStore)
            )
        }
        .onReceive(\.showDesktopSettings) { _ in
            settingsViewModel.navigator.navigate(
                LinkedDevicesView()
                    .environmentObject(settingsViewModel)
                    .environmentObject(settingsViewModel.navigator)
                    .environmentObject(settingsStore)
            )
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .listStyle(.insetGrouped)
        }
    }
}
