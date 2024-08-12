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

import Combine
import SwiftUI

struct PrivacySettingsView: View {
    
    @EnvironmentObject var settingsVM: SettingsStore

    @State private var contactsFooterText = BundleUtil
        .localizedString(forKey: "settings_privacy_block_unknown_footer_on")
    
    @State private var lockScreenWrapper = LockScreen(isLockScreenController: true)
    @State private var intermediaryHidePrivate = false
    
    @State private var readReceipts: SettingValueOption = .doSend
    @State private var typingIndicators: SettingValueOption = .doSend

    // Needed for refreshing after MD sync
    @State var observeSendReadReceipt: AnyCancellable?
    @State var observeSendTypingIndicator: AnyCancellable?

    let mdmSetup = MDMSetup(setup: false)
    let interactionFAQURLString = BundleUtil.object(forInfoDictionaryKey: "ThreemaInteractionInfo") as! String

    // MARK: - View

    var body: some View {
        
        List {
            // MARK: Contacts

            Section(
                header: Text("settings_privacy_contacts_header".localized),
                footer: Text(contactsFooterText)
            ) {
                Toggle(isOn: $settingsVM.syncContacts) {
                    Text("settings_privacy_sync_contacts".localized)
                }
                .disabled(mdmSetup?.existsMdmKey(MDM_KEY_CONTACT_SYNC) ?? false)
                    
                NavigationLink {
                    SyncExclusionListView()
                        .environmentObject(settingsVM)
                        .navigationBarTitle("settings_privacy_exclusion_list".localized)
                } label: {
                    Text("settings_privacy_exclusion_list".localized)
                }
                    
                Toggle(isOn: $settingsVM.blockUnknown) {
                    Text("settings_privacy_block_unknown".localized)
                }
                .disabled(mdmSetup?.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN) ?? false)
            }
            .onChange(of: settingsVM.blockUnknown) { _ in
                updateContactsFooter()
            }
            
            // MARK: OS Integration
            
            Section {
                Toggle(isOn: $settingsVM.allowOutgoingDonations) {
                    Text("settings_privacy_os_donate".localized)
                }
                if settingsVM.allowOutgoingDonations {
                    Button("settings_privacy_os_reset".localized, role: .destructive) {
                        settingsVM.removeINInteractions(showNotification: true)
                    }
                }
            } header: {
                Text("settings_privacy_os_header".localized)
            } footer: {
                VStack(alignment: .leading, spacing: 0) {
                    Text("settings_privacy_os_footer".localized)
                    Link(
                        "learn_more".localized,
                        destination: URL(string: interactionFAQURLString)!
                    )
                    .font(.footnote)
                }
            }
            
            // MARK: Chats

            Section(
                header: Text("settings_privacy_chat_header".localized),
                footer: Text("settings_privacy_hide_private_chats_footer".localized)
            ) {
                    
                NavigationLink {
                    PickerAndButtonView(
                        optionType: .readReceipt,
                        selectionType: $readReceipts
                    )
                    .environmentObject(settingsVM)
                } label: {
                    SettingsListItemView(
                        cellTitle: "settings_privacy_read_receipts".localized,
                        accessoryText: readReceipts.localizedDescription
                    )
                }
                    
                NavigationLink {
                    PickerAndButtonView(
                        optionType: .typingIndicator,
                        selectionType: $typingIndicators
                    )
                    .environmentObject(settingsVM)
                } label: {
                    SettingsListItemView(
                        cellTitle: "settings_privacy_typing_indicator".localized,
                        accessoryText: typingIndicators.localizedDescription
                    )
                }
                                    
                Toggle(isOn: $intermediaryHidePrivate) {
                    Text("settings_privacy_hide_private_chats".localized)
                }
                .onChange(of: intermediaryHidePrivate) { newValue in
                    hidePrivateChatsChanged(newValue)
                }
                .disabled(!KKPasscodeLock.shared().isPasscodeRequired())
            }
            
            // MARK: POI

            Section(
                header: Text("settings_privacy_poi_header".localized),
                footer: Text("settings_privacy_poi_footer".localized)
            ) {
                Toggle(isOn: $settingsVM.choosePOI) {
                    Text("settings_privacy_choose_poi".localized)
                }
            }
        }
        .listStyle(.insetGrouped)
        .disabled(settingsVM.isSyncing)
        .onAppear {
            observeSendReadReceipt = settingsVM.$sendReadReceipts.sink { newValue in
                readReceipts = newValue ? .doSend : .dontSend
            }
            observeSendTypingIndicator = settingsVM.$sendTypingIndicator.sink { newValue in
                typingIndicators = newValue ? .doSend : .dontSend
            }
            intermediaryHidePrivate = settingsVM.hidePrivateChats
            updateContactsFooter()
        }
        .alert(isPresented: $settingsVM.syncFailed, content: {
            Alert(
                title: Text("settings_md_sync_alert_title".localized),
                primaryButton: .default(Text("try_again".localized)) {
                    settingsVM.syncAndSave()
                },
                secondaryButton: .default(Text("cancel".localized)) {
                    settingsVM.discardUnsyncedChanges()
                }
            )
        })
        
        .navigationBarTitle("settings_list_privacy_title".localized, displayMode: .inline)
        .tint(UIColor.primary.color)
    }
    
    // MARK: - Private functions

    private func updateContactsFooter() {
        var footerText = settingsVM.blockUnknown ? BundleUtil
            .localizedString(forKey: "settings_privacy_block_unknown_footer_on") : BundleUtil
            .localizedString(forKey: "settings_privacy_block_unknown_foooter_off")
       
        if let mdmSetup, mdmSetup.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN) || mdmSetup.existsMdmKey(MDM_KEY_CONTACT_SYNC) {
            footerText = footerText + "\n\n" + "disabled_by_device_policy".localized
        }
        
        contactsFooterText = footerText
    }
    
    private func hidePrivateChatsChanged(_ hide: Bool) {
        if !hide {
            lockScreenWrapper.presentLockScreenView(
                viewController: AppDelegate.shared().currentTopViewController(),
                enteredCorrectly: {
                    settingsVM.hidePrivateChats = hide
                    NotificationCenter.default.post(
                        name: Notification.Name(kNotificationChangedHidePrivateChat),
                        object: nil,
                        userInfo: nil
                    )
                }, enteredIncorrectly: {
                    intermediaryHidePrivate = !hide
                }, unlockCancelled: {
                    intermediaryHidePrivate = !hide
                }
            )
        }
        else {
            settingsVM.hidePrivateChats = hide
            NotificationCenter.default.post(
                name: Notification.Name(kNotificationChangedHidePrivateChat),
                object: nil,
                userInfo: nil
            )
        }
    }
}

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PrivacySettingsView()
        }
        .tint(UIColor.primary.color)
        .environmentObject(BusinessInjector().settingsStore as! SettingsStore)
    }
}

// MARK: - Supporting Code

private enum SettingValueOption: CaseIterable {
    case doSend
    case dontSend
    
    var localizedDescription: String {
        switch self {
        case .doSend:
            "send".localized
        case .dontSend:
            "dont_send".localized
        }
    }
    
    var boolValue: Bool {
        switch self {
        case .doSend:
            true
        case .dontSend:
            false
        }
    }
}

private enum SettingType {
    case readReceipt
    case typingIndicator
    
    var navigationTitle: String {
        switch self {
        case .readReceipt:
            "settings_privacy_read_receipts".localized
        case .typingIndicator:
            "settings_privacy_typing_indicator".localized
        }
    }
}

private struct PickerAndButtonView: View {
    
    var optionType: SettingType
    
    @EnvironmentObject var settingsVM: SettingsStore
    @State var showResetAlert = false
    @Binding var selectionType: SettingValueOption

    var body: some View {
        Form {
            Section(header: Text("default_setting")) {
                Picker("", selection: $selectionType) {
                    ForEach(SettingValueOption.allCases, id: \.self) { option in
                        Text(option.localizedDescription)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .onChange(of: selectionType) { newValue in
                selectionType = newValue
                didSelect(newValue)
            }
            
            Section(footer: Text("settings_privacy_TIRR_reset_footer".localized)) {
                Button {
                    showResetAlert = true
                } label: {
                    Text("settings_privacy_TIRR_reset_all".localized)
                        .foregroundColor(.red)
                }
            }
        }
        .alert(
            "settings_privacy_TIRR_reset_alert_title".localized,
            isPresented: $showResetAlert,
            actions: {
                Button(role: .destructive) {
                    switch optionType {
                    case .readReceipt:
                        resetReadReceipts()
                    case .typingIndicator:
                        resetTypingIndicator()
                    }
                } label: {
                    Text("settings_privacy_TIRR_reset_alert_action".localized)
                }

            },
            message: {
                Text("settings_privacy_TIRR_reset_alert_message".localized)
            }
        )
        .navigationTitle(optionType.navigationTitle)
    }

    private func didSelect(_ newOption: SettingValueOption) {
        switch optionType {
        case .readReceipt:
            settingsVM.sendReadReceipts = newOption.boolValue
        case .typingIndicator:
            settingsVM.sendTypingIndicator = newOption.boolValue
        }
    }
    
    private func resetReadReceipts() {
        ContactStore.shared().resetCustomReadReceipts()
    }
    
    private func resetTypingIndicator() {
        let entityManager = EntityManager()
        
        guard let contacts = entityManager.entityFetcher.contactsWithCustomTypingIndicator() as? [ContactEntity] else {
            return
        }
        entityManager.performSyncBlockAndSafe {
            for contact in contacts {
                contact.typingIndicator = .default
            }
        }
    }
}

private struct SyncExclusionListView: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let storyboard = UIStoryboard(name: "SettingsStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "IDSyncExclusion")
        return vc
    }
}
