//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

struct PrivacySettingsView: View {
    
    @ObservedObject var settingsVM: SettingsStore

    @State private var contactsFooterText = BundleUtil
        .localizedString(forKey: "settings_privacy_block_unknown_footer_on")
    
    @State private var lockScreenWrapper = LockScreen(isLockScreenController: true)
    @State private var intermediaryHidePrivate = false
    
    @State private var readReceipts: SettingValueOption = .doSend
    @State private var typingIndicators: SettingValueOption = .doSend
    
    let mdmSetup = MDMSetup(setup: false)
    let interactionFAQURLString = BundleUtil.object(forInfoDictionaryKey: "ThreemaInteractionInfo") as! String

    // MARK: - View

    var body: some View {
        
        List {
            // MARK: Contacts

            Section(
                header: Text(BundleUtil.localizedString(forKey: "settings_privacy_contacts_header")),
                footer: Text(contactsFooterText)
            ) {
                Toggle(isOn: $settingsVM.syncContacts) {
                    Text(BundleUtil.localizedString(forKey: "settings_privacy_sync_contacts"))
                }
                .disabled(mdmSetup?.existsMdmKey(MDM_KEY_CONTACT_SYNC) ?? false)
                    
                NavigationLink {
                    SyncExclusionListView()
                        .navigationBarTitle(BundleUtil.localizedString(forKey: "settings_privacy_exclusion_list"))
                } label: {
                    Text(BundleUtil.localizedString(forKey: "settings_privacy_exclusion_list"))
                }
                    
                Toggle(isOn: $settingsVM.blockUnknown) {
                    Text(BundleUtil.localizedString(forKey: "settings_privacy_block_unknown"))
                }
                .disabled(mdmSetup?.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN) ?? false)
            }
            .onChange(of: settingsVM.blockUnknown) { _ in
                updateContactsFooter()
            }
            
            // MARK: OS Integration
            
            Section {
                Toggle(isOn: $settingsVM.allowOutgoingDonations) {
                    Text(BundleUtil.localizedString(forKey: "settings_privacy_os_donate"))
                }
                if settingsVM.allowOutgoingDonations {
                    Button(BundleUtil.localizedString(forKey: "settings_privacy_os_reset"), role: .destructive) {
                        settingsVM.removeINInteractions(showNotification: true)
                    }
                }
            } header: {
                Text(BundleUtil.localizedString(forKey: "settings_privacy_os_header"))
            } footer: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(BundleUtil.localizedString(forKey: "settings_privacy_os_footer"))
                    Link(
                        BundleUtil.localizedString(forKey: "learn_more"),
                        destination: URL(string: interactionFAQURLString)!
                    )
                    .font(.footnote)
                }
            }
            
            // MARK: Chats

            Section(
                header: Text(BundleUtil.localizedString(forKey: "settings_privacy_chat_header")),
                footer: Text(BundleUtil.localizedString(forKey: "settings_privacy_hide_private_chats_footer"))
            ) {
                    
                NavigationLink {
                    PickerAndButtonView(
                        optionType: .readReceipt,
                        settingsVM: settingsVM,
                        selectionType: $readReceipts
                    )
                } label: {
                    HStack {
                        Text(BundleUtil.localizedString(forKey: "settings_privacy_read_receipts"))
                        Spacer()
                        Text(readReceipts.localizedDescription)
                            .foregroundColor(.secondary)
                    }
                }
                    
                NavigationLink {
                    PickerAndButtonView(
                        optionType: .typingIndicator,
                        settingsVM: settingsVM,
                        selectionType: $typingIndicators
                    )
                } label: {
                    HStack {
                        Text(BundleUtil.localizedString(forKey: "settings_privacy_typing_indicator"))
                        Spacer()
                        Text(typingIndicators.localizedDescription)
                            .foregroundColor(.secondary)
                    }
                }
                    
                Toggle(isOn: $settingsVM.choosePOI) {
                    Text(BundleUtil.localizedString(forKey: "settings_privacy_choose_poi"))
                }
                
                Toggle(isOn: $intermediaryHidePrivate) {
                    Text(BundleUtil.localizedString(forKey: "settings_privacy_hide_private_chats"))
                }
                .onChange(of: intermediaryHidePrivate) { newValue in
                    hidePrivateChatsChanged(newValue)
                }
                .disabled(!KKPasscodeLock.shared().isPasscodeRequired())
            }
        }
        .listStyle(.insetGrouped)
        .disabled(settingsVM.isSyncing)
        
        .onAppear {
            setUpValues()
            updateContactsFooter()
        }
        .alert(isPresented: $settingsVM.syncFailed, content: {
            Alert(
                title: Text(BundleUtil.localizedString(forKey: "settings_md_sync_alert_title")),
                primaryButton: .default(Text(BundleUtil.localizedString(forKey: "try_again"))) {
                    settingsVM.syncAndSave()
                },
                secondaryButton: .default(Text(BundleUtil.localizedString(forKey: "cancel"))) {
                    settingsVM.discardUnsyncedChanges()
                }
            )
        })
        
        .navigationBarTitle(BundleUtil.localizedString(forKey: "settings_list_privacy_title"), displayMode: .inline)
        .tint(UIColor.primary.color)
    }
    
    // MARK: - Private functions

    private func updateContactsFooter() {
        var footerText = settingsVM.blockUnknown ? BundleUtil
            .localizedString(forKey: "settings_privacy_block_unknown_footer_on") : BundleUtil
            .localizedString(forKey: "settings_privacy_block_unknown_foooter_off")
       
        if let mdmSetup, mdmSetup.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN) || mdmSetup.existsMdmKey(MDM_KEY_CONTACT_SYNC) {
            footerText = footerText + "\n\n" + BundleUtil.localizedString(forKey: "disabled_by_device_policy")
        }
        
        contactsFooterText = footerText
    }
    
    private func setUpValues() {
        readReceipts = settingsVM.sendReadReceipts ? .doSend : .dontSend
        typingIndicators = settingsVM.sendTypingIndicator ? .doSend : .dontSend
        intermediaryHidePrivate = settingsVM.hidePrivateChats
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
            PrivacySettingsView(settingsVM: SettingsStore())
        }
        .tint(UIColor.primary.color)
        .environmentObject(SettingsStore())
    }
}

// MARK: - Supporting Code

private enum SettingValueOption: CaseIterable {
    case doSend
    case dontSend
    
    var localizedDescription: String {
        switch self {
        case .doSend:
            return BundleUtil.localizedString(forKey: "send")
        case .dontSend:
            return BundleUtil.localizedString(forKey: "dont_send")
        }
    }
    
    var boolValue: Bool {
        switch self {
        case .doSend:
            return true
        case .dontSend:
            return false
        }
    }
}

private enum SettingType {
    case readReceipt
    case typingIndicator
    
    var navigationTitle: String {
        switch self {
        case .readReceipt:
            return BundleUtil.localizedString(forKey: "settings_privacy_read_receipts")
        case .typingIndicator:
            return BundleUtil.localizedString(forKey: "settings_privacy_typing_indicator")
        }
    }
}

private struct PickerAndButtonView: View {
    
    var optionType: SettingType
    
    @ObservedObject var settingsVM: SettingsStore
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
            
            Section(footer: Text(BundleUtil.localizedString(forKey: "settings_privacy_TIRR_reset_footer"))) {
                Button {
                    showResetAlert = true
                } label: {
                    Text(BundleUtil.localizedString(forKey: "settings_privacy_TIRR_reset_all"))
                        .foregroundColor(.red)
                }
            }
        }
        .alert(
            BundleUtil.localizedString(forKey: "settings_privacy_TIRR_reset_alert_title"),
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
                    Text(BundleUtil.localizedString(forKey: "settings_privacy_TIRR_reset_alert_action"))
                }

            },
            message: {
                Text(BundleUtil.localizedString(forKey: "settings_privacy_TIRR_reset_alert_message"))
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
        let entityManager = EntityManager()
        
        guard let contacts = entityManager.entityFetcher.contactsWithCustomReadReceipt() as? [ContactEntity] else {
            return
        }
        entityManager.performSyncBlockAndSafe {
            for contact in contacts {
                contact.readReceipt = .default
            }
        }
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
