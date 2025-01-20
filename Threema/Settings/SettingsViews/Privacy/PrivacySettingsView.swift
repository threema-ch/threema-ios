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

import Combine
import SwiftUI
import ThreemaMacros

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
                header: Text(#localize("settings_privacy_contacts_header")),
                footer: Text(contactsFooterText)
            ) {
                Toggle(isOn: $settingsVM.syncContacts) {
                    Text(#localize("settings_privacy_sync_contacts"))
                }
                .disabled(mdmSetup?.existsMdmKey(MDM_KEY_CONTACT_SYNC) ?? false)
                    
                NavigationLink {
                    SyncExclusionListView()
                        .environmentObject(settingsVM)
                } label: {
                    Text(#localize("settings_privacy_exclusion_list"))
                }
                    
                Toggle(isOn: $settingsVM.blockUnknown) {
                    Text(#localize("settings_privacy_block_unknown"))
                }
                .disabled(mdmSetup?.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN) ?? false)
                
                NavigationLink {
                    BlockListView()
                        .environmentObject(settingsVM)
                } label: {
                    Text(#localize("settings_privacy_blocklist"))
                }
            }
            .onChange(of: settingsVM.blockUnknown) { _ in
                updateContactsFooter()
            }
            
            // MARK: OS Integration
            
            Section {
                Toggle(isOn: $settingsVM.allowOutgoingDonations) {
                    Text(#localize("settings_privacy_os_donate"))
                }
                if settingsVM.allowOutgoingDonations {
                    Button(#localize("settings_privacy_os_reset"), role: .destructive) {
                        settingsVM.removeINInteractions(showNotification: true)
                    }
                }
            } header: {
                Text(#localize("settings_privacy_os_header"))
            } footer: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(#localize("settings_privacy_os_footer"))
                    Link(
                        #localize("learn_more"),
                        destination: URL(string: interactionFAQURLString)!
                    )
                    .font(.footnote)
                }
            }
            
            // MARK: Chats

            Section(
                header: Text(#localize("settings_privacy_chat_header")),
                footer: Text(#localize("settings_privacy_hide_private_chats_footer"))
            ) {
                    
                NavigationLink {
                    PickerAndButtonView(
                        optionType: .readReceipt,
                        selectionType: $readReceipts
                    )
                    .environmentObject(settingsVM)
                } label: {
                    SettingsListItemView(
                        cellTitle: #localize("settings_privacy_read_receipts"),
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
                        cellTitle: #localize("settings_privacy_typing_indicator"),
                        accessoryText: typingIndicators.localizedDescription
                    )
                }
                                    
                Toggle(isOn: $intermediaryHidePrivate) {
                    Text(#localize("settings_privacy_hide_private_chats"))
                }
                .onChange(of: intermediaryHidePrivate) { newValue in
                    hidePrivateChatsChanged(newValue)
                }
                .disabled(!KKPasscodeLock.shared().isPasscodeRequired())
            }
            
            // MARK: POI

            Section(
                header: Text(#localize("settings_privacy_poi_header")),
                footer: Text(#localize("settings_privacy_poi_footer"))
            ) {
                Toggle(isOn: $settingsVM.choosePOI) {
                    Text(#localize("settings_privacy_choose_poi"))
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
                title: Text(#localize("settings_md_sync_alert_title")),
                primaryButton: .default(Text(#localize("try_again"))) {
                    settingsVM.syncAndSave()
                },
                secondaryButton: .default(Text(#localize("cancel"))) {
                    settingsVM.discardUnsyncedChanges()
                }
            )
        })
        
        .navigationBarTitle(#localize("settings_list_privacy_title"), displayMode: .inline)
        .tint(UIColor.primary.color)
    }
    
    // MARK: - Private functions

    private func updateContactsFooter() {
        var footerText = settingsVM.blockUnknown ? BundleUtil
            .localizedString(forKey: "settings_privacy_block_unknown_footer_on") : BundleUtil
            .localizedString(forKey: "settings_privacy_block_unknown_foooter_off")
       
        if let mdmSetup, mdmSetup.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN) || mdmSetup.existsMdmKey(MDM_KEY_CONTACT_SYNC) {
            footerText = footerText + "\n\n" + #localize("disabled_by_device_policy")
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
            #localize("send")
        case .dontSend:
            #localize("dont_send")
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
            #localize("settings_privacy_read_receipts")
        case .typingIndicator:
            #localize("settings_privacy_typing_indicator")
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
            
            Section(footer: Text(#localize("settings_privacy_TIRR_reset_footer"))) {
                Button {
                    showResetAlert = true
                } label: {
                    Text(#localize("settings_privacy_TIRR_reset_all"))
                        .foregroundColor(.red)
                }
            }
        }
        .alert(
            #localize("settings_privacy_TIRR_reset_alert_title"),
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
                    Text(#localize("settings_privacy_TIRR_reset_alert_action"))
                }

            },
            message: {
                Text(#localize("settings_privacy_TIRR_reset_alert_message"))
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
