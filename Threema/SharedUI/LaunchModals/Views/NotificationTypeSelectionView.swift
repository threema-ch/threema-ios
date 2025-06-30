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

struct NotificationTypeSelectionView: View {
    @Environment(\.dismiss) var dismiss

    @State var showPreview: Bool
    @State var selectedType: NotificationType
    let disablePreviewToggle = MDMSetup(setup: false).existsMdmKey(MDM_KEY_DISABLE_MESSAGE_PREVIEW)
    @ObservedObject var settingsStore: SettingsStore
    
    private let cornerRadius = 20.0
    private let padding = 16.0
    
    init() {
        let settingsStore = BusinessInjector.ui.settingsStore as! SettingsStore
        _settingsStore = ObservedObject(initialValue: settingsStore)
        _selectedType = State(initialValue: settingsStore.notificationType)
        _showPreview = State(initialValue: settingsStore.pushShowPreview)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(#localize("settings_notification_type_preview_title"))
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(String.localizedStringWithFormat(
                    #localize("settings_notification_type_preview_description"),
                    TargetManager.appName
                ))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
                
                ForEach(NotificationType.allCases, id: \.self) { notificationType in
                    NotificationTypeView(
                        selectedType: $selectedType,
                        showPreview: $showPreview,
                        notificationType: notificationType,
                        inApp: false
                    )
                    .padding()
                    .background(UIColor.secondarySystemGroupedBackground.color)
                    .cornerRadius(cornerRadius)
                    .overlay {
                        if selectedType == notificationType {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.accentColor, lineWidth: 2.5)
                        }
                    }
                }
                
                Toggle(isOn: $showPreview) {
                    Text(#localize("settings_notifications_push_preview"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(UIColor.secondarySystemGroupedBackground.color)
                .cornerRadius(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .disabled(disablePreviewToggle)
                
                if disablePreviewToggle {
                    Text(#localize("disabled_by_device_policy"))
                        .font(.footnote)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                
                VStack(spacing: 16) {
                    Button {
                        continueTapped()
                        AppGroup.userDefaults().set(true, forKey: Constants.showedNotificationTypeSelectionView)
                        dismiss()
                    } label: {
                        Text(#localize("continue"))
                            .font(.title3)
                            .bold()
                            .foregroundColor(Colors.textProminentButton.color)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .cornerRadius(16)
                    }
                }
                .padding(.top)
            }
            .padding()
            .padding(.vertical)
        }
        .tint(.accentColor)
        .background(UIColor.systemGroupedBackground.color)
        .interactiveDismissDisabled()
        .onDisappear {
            // TODO: (IOS-3251) Remove
            LaunchModalManager.shared.checkLaunchModals()
        }
    }
    
    // MARK: - Private Functions
    
    private func continueTapped() {
        settingsStore.pushShowPreview = showPreview
        settingsStore.notificationType = selectedType
        settingsStore.allowOutgoingDonations = selectedType == .complete
    }
}

// MARK: - Preview

struct NotificationTypeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationTypeSelectionView()
            .tint(.accentColor)
    }
}
