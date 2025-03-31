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
import ThreemaMacros

struct NotificationReminderView: View {
    
    @Environment(\.dismiss) var dismiss
    
    // MARK: - View

    var body: some View {
        VStack {
            Spacer()
            
            Image(systemName: "exclamationmark.bubble.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(Color(uiColor: Colors.red))
                .padding(25)
            
            Text(
                String.localizedStringWithFormat(
                    #localize("push_reminder_message"),
                    TargetManager.appName,
                    TargetManager.appName,
                    TargetManager.appName
                )
            )
            .font(.title3)
            .bold()
            .multilineTextAlignment(.center)
            
            Spacer()
            Spacer()

            Button {
                setReminder()
            } label: {
                Text(#localize("push_reminder_set_now"))
                    .font(.title3)
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            
            Button {
                AppGroup.userDefaults().set(true, forKey: "PushReminderDoNotShowAgain")
                dismiss()
            } label: {
                Text(#localize("push_reminder_not_now"))
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .padding(.bottom, 15)
        }
        .padding()
        .interactiveDismissDisabled()
        .onDisappear {
            // TODO: (IOS-3251) Remove
            LaunchModalManager.shared.checkLaunchModals()
        }
    }
    
    // MARK: - Private Functions

    private func setReminder() {
        let settingsURL =
            if #available(iOS 16.0, *) {
                URL(string: UIApplication.openNotificationSettingsURLString)!
            }
            else {
                // Fallback on earlier versions
                URL(string: UIApplication.openSettingsURLString)!
            }
        UIApplication.shared.open(settingsURL)
    }
}

struct NotificationReminderView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationReminderView()
            .tint(UIColor.primary.color)
    }
}
