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

struct ContactsCleanupView: View {
    @StateObject var settingsStore = BusinessInjector().settingsStore as! SettingsStore

    @State private var showLogDisabledError = false
    @State private var showNoDuplicatesError = false
    @State private var showDuplicatesInUseError = false
    @State private var showUnusedContactsCleanupDone = false
    @State private var showContactStatsLogged = false
    @State private var alertMessage = ""

    var body: some View {
        List {
            Section {
                Button {
                    showContactStatsLogged = logContactStats()
                } label: {
                    HStack {
                        Spacer()
                        Text(BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup_log_stats"))
                        Spacer()
                    }
                }
                if SettingsBundleHelper.safeMode {
                    Button {
                        cleanupUnusedContacts()
                    } label: {
                        HStack {
                            Spacer()
                            Text(BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup_unused"))
                            Spacer()
                        }
                    }
                }
            } header: {
                Text(BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup_stats_title"))
            }
        }
        .alert(
            BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup_log_disabled"),
            isPresented: $showLogDisabledError
        ) {
            Button("OK") { }
        }
        .alert(
            BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup_stats_logged") +
                BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup_submit_logs"),
            isPresented: $showContactStatsLogged
        ) {
            Button("OK") { }
        }
        .alert(
            BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup_no_duplicates"),
            isPresented: $showNoDuplicatesError
        ) {
            Button("OK") { }
        }
        .alert(
            BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup_error_title"),
            isPresented: $showDuplicatesInUseError
        ) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert(
            BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup_success_title"),
            isPresented: $showUnusedContactsCleanupDone
        ) {
            Button(BundleUtil.localizedString(forKey: "settings_advanced_contacts_cleanup_success_exit")) {
                exitSafeMode()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Private Functions

    // the following function returns a simplified unique ID representation, good enough for
    // logging/sorting objects from the same entity manager / DB
    fileprivate func getCoreDataID(_ obj: NSManagedObject)
        -> Int { Int(obj.objectID.uriRepresentation().lastPathComponent.dropFirst()) ?? -1
    }
    
    /// Log duplicate contact statistics
    ///
    /// Shows alert if debug log is not enabled or if there are no duplicates.
    /// Returns true if stats were logged.
    private func logContactStats() -> Bool {
        let ISOFormatter = ISO8601DateFormatter()
        let entityManager = BusinessInjector().entityManager

        guard settingsStore.validationLogging else {
            showLogDisabledError = true
            return false
        }

        var duplicates: NSSet?
        if !entityManager.entityFetcher.hasDuplicateContacts(
            withDuplicateIdentities: &duplicates
        ) {
            showNoDuplicatesError = true
            DDLogNotice("No duplicate contacts found")
            return false
        }
        
        let duplicateContactIdentities = Array(duplicates as? Set<String> ?? []).sorted()
        
        DDLogNotice("Statistics for duplicate contacts (\(duplicateContactIdentities.count) Threema IDs affected)")
        for id in duplicateContactIdentities {
            guard let contacts = entityManager.entityFetcher.allContacts(forID: id) as? [ContactEntity],
                  !contacts.isEmpty else {
                DDLogNotice("Duplicate contacts not found for ID: \(id)")
                continue
            }
            
            // sort to ensure that output ordering is stable across runs
            let sortedContacts = contacts.sorted { getCoreDataID($0) < getCoreDataID($1) }
            // partially hide ID for privacy reasons
            let partialID = "****" + id.dropFirst(4)
            
            for contact in sortedContacts {
                // note: total message count can be higher than sum of message
                let contactCreatedAt = contact.createdAt != nil ? ISOFormatter
                    .string(from: contact.createdAt!) : "-"
                let contactTotalMessageCount: Int = entityManager.entityFetcher.countMessages(forContact: contact)
                let partialCnContactID = contact.cnContactID?.prefix(8) ?? "-"
                let prefix =
                    "ID=\(partialID), ContactID=\(getCoreDataID(contact)), ContactCreatedAt=\(contactCreatedAt), ContactHidden=\(contact.isContactHidden), Contact#Msg=\(contactTotalMessageCount), LinkedContact=\(partialCnContactID)"

                let conversations = getAllConversations(contact: contact)

                if !conversations.isEmpty {
                    // sort to ensure that output ordering is stable across runs
                    let sortedConversations = conversations.sorted { getCoreDataID($0) < getCoreDataID($1) }
                    
                    for conversation in sortedConversations {
                        let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
                        let messageCount = messageFetcher.count()
                        let contactConversationMessageCount: Int = entityManager.entityFetcher.countMessagesForContact(
                            inConversation: contact,
                            for: conversation
                        )
                        
                        let groupInfo: String
                        if let group = entityManager.entityFetcher.groupEntity(for: conversation) {
                            groupInfo = ", GroupID=\(getCoreDataID(group)), GroupState=\(group.state)"
                        }
                        else {
                            groupInfo = ", GroupID=-"
                        }
                        
                        let convType = conversation.isGroup() ? "Group" : "OneToOne"
                        let convLastUpdate = conversation.lastUpdate != nil ? ISOFormatter
                            .string(from: conversation.lastUpdate!) : "-"
                        
                        DDLogNotice(
                            "\(prefix), #Conversations=\(conversations.count), ConvID=\(getCoreDataID(conversation)), ConvType=\(convType), Conv#MsgTotal=\(messageCount), Conv#MsgContact=\(contactConversationMessageCount), ConvLastUpdate=\(convLastUpdate)\(groupInfo)"
                        )
                    }
                }
                else {
                    DDLogNotice("\(prefix), #Conversations=0")
                }
            }
        }

        return true
    }
    
    /// Returns all conversations for the contact, empty set if none
    fileprivate func getAllConversations(contact: ContactEntity) -> Set<Conversation> {
        let conversations = Set<Conversation>(
            contact
                .conversations as? Set<Conversation> ?? Set<Conversation>()
        )
        let groupConversations = Set<Conversation>(
            contact
                .groupConversations as? Set<Conversation> ?? Set<Conversation>()
        )
        return conversations.union(groupConversations)
    }
    
    /// Remove contacts if they have no conversation and no messages.
    ///
    /// Only do the cleanup if no duplicates remain afterward, because otherwise, this doesn't really help
    /// the user. In the latter case, they have to wait for a more sophisticated cleanup algorithm.
    private func cleanupUnusedContacts() {
        guard SettingsBundleHelper.safeMode, logContactStats() else {
            return
        }
        
        let entityManager = BusinessInjector().entityManager

        var duplicates: NSSet?
        if !entityManager.entityFetcher.hasDuplicateContacts(
            withDuplicateIdentities: &duplicates
        ) {
            showNoDuplicatesError = true
            DDLogNotice("No duplicate contacts found")
            return
        }

        let duplicateContactIdentities = Array(duplicates as? Set<String> ?? []).sorted()
        
        var removableContacts = [ContactEntity]()
        var unremovableContacts = [ContactEntity]()

        for id in duplicateContactIdentities {
            guard let contacts = entityManager.entityFetcher.allContacts(forID: id) as? [ContactEntity],
                  contacts.count > 1 else {
                DDLogNotice("Duplicate contacts not found for ID: \(id)")
                continue
            }

            // sort to ensure that output ordering is stable across runs
            var sortedContactsToRemove = contacts.sorted { getCoreDataID($0) < getCoreDataID($1) }

            // we keep the first contact (lowest internal ID) that belongs to the current id
            sortedContactsToRemove.remove(at: 0)

            // partially hide ID for privacy reasons
            let partialID = "****" + id.dropFirst(4)
            
            for contact in sortedContactsToRemove {
                let contactTotalMessageCount: Int = entityManager.entityFetcher.countMessages(forContact: contact)
                let conversations = getAllConversations(contact: contact)
                
                if contactTotalMessageCount == 0, conversations.isEmpty {
                    removableContacts.append(contact)
                    DDLogNotice("Duplicate contact to be removed: ID=\(partialID), ContactID=\(getCoreDataID(contact))")
                }
                else {
                    DDLogNotice(
                        "Duplicate contact will not be removed because it is still in use: ID=\(partialID), ContactID=\(getCoreDataID(contact)), Contact#Msg=\(contactTotalMessageCount), #Conversations=\(conversations.count)"
                    )
                    unremovableContacts.append(contact)
                }
            }
        }
        
        guard unremovableContacts.isEmpty else {
            DDLogNotice(
                "Contact cleanup aborted: \(unremovableContacts.count) duplicates still have messages or are member of group chats."
            )

            alertMessage = String(
                format: BundleUtil
                    .localizedString(forKey: "settings_advanced_contacts_cleanup_still_used_error") + BundleUtil
                    .localizedString(forKey: "settings_advanced_contacts_cleanup_submit_logs"),
                unremovableContacts.count
            )
            showDuplicatesInUseError = true

            return
        }
        
        entityManager.cleanupUnusedContacts(removableContacts)
        DDLogNotice("\(removableContacts.count) duplicate contacts removed")

        alertMessage = String(
            format: BundleUtil
                .localizedString(forKey: "settings_advanced_contacts_cleanup_unused_message") + BundleUtil
                .localizedString(forKey: "settings_advanced_contacts_cleanup_submit_logs"),
            removableContacts.count
        )
        showUnusedContactsCleanupDone = true
    }
    
    private func exitSafeMode() {
        SettingsBundleHelper.resetSafeMode()
        DDLogNotice("Exiting app to leave safe mode")
        DDLog.flushLog()
        exit(EXIT_SUCCESS)
    }
}

class ContactsCleanupViewHostingController: UIHostingController<ContactsCleanupView> {
    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: ContactsCleanupView())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
