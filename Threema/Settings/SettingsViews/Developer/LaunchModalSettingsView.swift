//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
            
            Section("Show Modals") {
                Button {
                    showNotificationReminderView.toggle()
                } label: {
                    Text("Notification Reminder")
                }
                .sheet(isPresented: $showNotificationReminderView) {
                    NotificationReminderView()
                }
                
                Button {
                    showNotificationTypeSelectionView.toggle()
                } label: {
                    Text("Notification Type Selection")
                }
                .sheet(isPresented: $showNotificationTypeSelectionView) {
                    NotificationTypeSelectionView()
                }
                
                Button {
                    showFeedBackView.toggle()
                } label: {
                    Text("Beta Feedback")
                }
                .sheet(isPresented: $showFeedBackView) {
                    BetaFeedbackView()
                }
            }
            
            Section("Reset") {
                Button(role: .destructive) {
                    resetNotificationTypeSelection()
                } label: {
                    Text("Notification Type Selection")
                }
                
                Button(role: .destructive) {
                    resetBetaFeedback()
                } label: {
                    Text("Beta Feedback")
                }
                
                Button(role: .destructive) {
                    resetSafeIntroShown()
                } label: {
                    Text("Safe Intro")
                }
            }
            
            Section {
                Button(role: .destructive) {
                    resetNotificationTypeSelection()
                    resetBetaFeedback()
                    resetSafeIntroShown()
                } label: {
                    Text("Reset All")
                }
            }
        }
        .navigationTitle("Launch Modals")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func resetBetaFeedback() {
        AppGroup.userDefaults().set(false, forKey: Constants.betaFeedbackIdentity)
    }
    
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
                .accentColor(UIColor.primary.color)
        }
    }
}
