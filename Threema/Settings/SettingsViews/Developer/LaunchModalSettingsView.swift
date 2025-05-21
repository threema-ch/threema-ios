//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

struct LaunchModalSettingsView: View {
    @State var showNotificationReminderView = false
    @State var showNotificationTypeSelectionView = false
    @State var showFeedBackView = false

    var body: some View {
        List {
            Section {
                Button {
                    showNotificationReminderView.toggle()
                } label: {
                    Text(verbatim: "Notification Reminder")
                }
                .sheet(isPresented: $showNotificationReminderView) {
                    NotificationReminderView()
                }
                
                Button {
                    showNotificationTypeSelectionView.toggle()
                } label: {
                    Text(verbatim: "Notification Type Selection")
                }
                .sheet(isPresented: $showNotificationTypeSelectionView) {
                    NotificationTypeSelectionView()
                }
            } header: {
                Text(verbatim: "Show Modals")
            }
            
            Section {
                Button(role: .destructive) {
                    resetNotificationTypeSelection()
                } label: {
                    Text(verbatim: "Notification Type Selection")
                }
                
                Button(role: .destructive) {
                    resetSafeIntroShown()
                } label: {
                    Text(verbatim: "Safe Intro")
                }
            } header: {
                Text(verbatim: "Reset")
            }
            
            Section {
                Button(role: .destructive) {
                    resetNotificationTypeSelection()
                    resetSafeIntroShown()
                } label: {
                    Text(verbatim: "Reset All")
                }
            }
        }
        .navigationTitle(Text(verbatim: "Launch Modals"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Private functions
    
    private func resetNotificationTypeSelection() {
        AppGroup.userDefaults().set(false, forKey: Constants.showedNotificationTypeSelectionView)
    }
    
    private func resetSafeIntroShown() {
        UserSettings.shared().safeIntroShown = false
    }
}

struct LaunchModalResetView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LaunchModalSettingsView()
        }
    }
}
