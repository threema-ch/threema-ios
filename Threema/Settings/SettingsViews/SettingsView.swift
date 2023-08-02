//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
    @StateObject var settingsStore = BusinessInjector().settingsStore as! SettingsStore
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                if ThreemaEnvironment.env() != .appStore {
                    Section {
                        NavigationLink {
                            DeveloperSettingsView()
                        } label: {
                            SettingsListView(cellTitle: "Developer Settings", imageSystemName: "ant.fill")
                        }
                    }
                }
                
                Section {
                    NavigationLink {
                        PrivacySettingsView(settingsVM: settingsStore)
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_privacy_title"),
                            imageSystemName: "hand.raised.fill"
                        )
                    }
                    
                    NavigationLink {
                        AppearanceSettingsViewControllerRepresentable()
                            .ignoresSafeArea(.all)
                            .navigationBarTitle(
                                BundleUtil.localizedString(forKey: "settings_list_appearance_title"),
                                displayMode: .inline
                            )
                        
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_appearance_title"),
                            imageSystemName: "paintbrush.fill"
                        )
                    }

                    NavigationLink {
                        NotificationSettingsView(settingsVM: settingsStore)
                        
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_notifications_title"),
                            imageSystemName: "app.badge"
                        )
                    }
                    
                    NavigationLink {
                        ChatSettingsView(settingsVM: settingsStore)
                        
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_chat_title"),
                            imageSystemName: "bubble.left.and.bubble.right.fill"
                        )
                    }
                    
                    NavigationLink {
                        MediaSettingsView()
                    } label: {
                        SettingsListView(cellTitle: "Medien", imageSystemName: "photo.fill")
                    }
                    
                    NavigationLink {
                        StorageManagementViewControllerRepresentable()
                            .ignoresSafeArea(.all)
                            .navigationBarTitle(
                                BundleUtil.localizedString(forKey: "settings_list_storage_management_title"),
                                displayMode: .inline
                            )
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_storage_management_title"),
                            imageSystemName: "tray.full.fill"
                        )
                    }
                    
                    NavigationLink {
                        PasscodeViewControllerRepresentable()
                            .ignoresSafeArea(.all)
                            .navigationBarTitle(
                                BundleUtil.localizedString(forKey: "settings_list_passcode_lock_title"),
                                displayMode: .inline
                            )
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_passcode_lock_title"),
                            imageSystemName: "lock.fill"
                        )
                    }
                }
                
                Section {
                    NavigationLink {
                        CallSettingsView()
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_threema_calls"),
                            imageSystemName: "phone.fill"
                        )
                    }
                    
                    NavigationLink {
                        ThreemaWebViewControllerRepresentable()
                            .ignoresSafeArea(.all)
                            .navigationBarTitle(
                                BundleUtil.localizedString(forKey: "settings_list_threema_web_title"),
                                displayMode: .inline
                            )
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_threema_web_title"),
                            imageSystemName: "desktopcomputer"
                        )
                    }
                }
                
                Section {
                    NavigationLink {
                        LinkedDevicesView(settingsStore: settingsStore)
                    } label: {
                        SettingsListView(
                            cellTitle: "WIP: Linked Device (beta)",
                            imageSystemName: "laptopcomputer.and.iphone"
                        )
                    }
                }
                
                Section {
                    HStack {
                        Text(BundleUtil.localizedString(forKey: "settings_list_network_title"))
                        Spacer()
                        Text("Connected")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(BundleUtil.localizedString(forKey: "settings_list_version_title"))
                        Spacer()
                        Text("settings_list_version_title")
                            .foregroundColor(.secondary)
                    }
                    
                    if LicenseStore.requiresLicenseKey() {
                        HStack {
                            Text(BundleUtil.localizedString(forKey: "settings_list_settings_license_username_title"))
                            Spacer()
                            Text("Connected")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !LicenseStore.requiresLicenseKey() {
                    Section {
                        NavigationLink {
                            EmptyView()

                        } label: {
                            SettingsListView(
                                cellTitle: BundleUtil.localizedString(forKey: "settings_list_invite_a_friend_title"),
                                imageSystemName: "person.2.wave.2.fill"
                            )
                        }
                        
                        NavigationLink {
                            EmptyView()
                        } label: {
                            SettingsListView(
                                cellTitle: BundleUtil.localizedString(forKey: "settings_list_threema_channel_title"),
                                imageSystemName: "antenna.radiowaves.left.and.right"
                            )
                        }
                    }
                }
                
                Section {
                    NavigationLink {
                        EmptyView()
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_support_title"),
                            imageSystemName: "lightbulb.fill"
                        )
                    }
                    
                    NavigationLink {
                        EmptyView()
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_privacy_policy_title"),
                            imageSystemName: "lock.shield.fill"
                        )
                    }
                    
                    NavigationLink {
                        EmptyView()
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_tos_title"),
                            imageSystemName: "signature"
                        )
                    }
                    
                    NavigationLink {
                        EmptyView()
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_list_license_title"),
                            imageSystemName: "c.circle"
                        )
                    }
                    
                    NavigationLink {
                        AdvancedSettingsView(settingsVM: settingsStore)
                    } label: {
                        SettingsListView(
                            cellTitle: BundleUtil.localizedString(forKey: "settings_advanced"),
                            imageSystemName: "hammer.fill"
                        )
                    }
                }
            }
            .navigationBarTitle(BundleUtil.localizedString(forKey: "settings_navbar_title"), displayMode: .inline)
        }
        .environmentObject(settingsStore)
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

// MARK: - UIViewControllerRepresentable

struct PasscodeViewControllerRepresentable: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        KKPasscodeSettingsViewController(style: .grouped)
    }
}
