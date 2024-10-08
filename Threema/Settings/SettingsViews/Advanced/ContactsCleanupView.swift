//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import CocoaLumberjackSwift
import SwiftUI

struct ContactsCleanupView: View {
    @StateObject var settingsStore = BusinessInjector().settingsStore as! SettingsStore

    @State private var showLogDisabledError = false
    @State private var showNoDuplicatesError = false
    @State private var showDuplicatesInUseError = false
    @State private var showMultiDeviceEnabledError = false
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
                        Text("settings_advanced_contacts_cleanup_log_stats".localized)
                        Spacer()
                    }
                }
                if SettingsBundleHelper.safeMode {
                    Button {
                        cleanupDuplicateContacts()
                    } label: {
                        HStack {
                            Spacer()
                            Text("settings_advanced_contacts_cleanup_unused".localized)
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("settings_advanced_contacts_cleanup_stats_title".localized)
            }
        }
        .alert(
            "settings_advanced_contacts_cleanup_log_disabled".localized,
            isPresented: $showLogDisabledError
        ) {
            Button("OK") { }
        }
        .alert(
            "settings_advanced_contacts_cleanup_stats_logged".localized +
                "settings_advanced_contacts_cleanup_submit_logs".localized,
            isPresented: $showContactStatsLogged
        ) {
            Button("OK") { }
        }
        .alert(
            "settings_advanced_contacts_cleanup_no_duplicates".localized,
            isPresented: $showNoDuplicatesError
        ) {
            Button("OK") { }
        }
        .alert(
            "settings_advanced_contacts_cleanup_in_use_error_title".localized,
            isPresented: $showDuplicatesInUseError
        ) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert(
            "settings_advanced_contacts_cleanup_error_title".localized,
            isPresented: $showMultiDeviceEnabledError
        ) {
            Button("OK") { }
        } message: {
            Text("settings_advanced_contacts_multi_device_enabled_error".localized)
        }
        .alert(
            "settings_advanced_contacts_cleanup_success_title".localized,
            isPresented: $showUnusedContactsCleanupDone
        ) {
            Button("settings_advanced_contacts_cleanup_success_exit".localized) {
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

        return entityManager.performAndWait {
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
                            let contactConversationMessageCount: Int = entityManager.entityFetcher
                                .countMessagesForContact(
                                    inConversation: contact,
                                    for: conversation
                                )
                            
                            let groupInfo =
                                if let group = entityManager.entityFetcher.groupEntity(for: conversation) {
                                    ", GroupID=\(getCoreDataID(group)), GroupState=\(group.state)"
                                }
                                else {
                                    ", GroupID=-"
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
    
    /// Iterate over all messages sent by the given duplicates and update the sender to the given main contact
    fileprivate func updateMessageSenderToMainContact(
        duplicateContacts: [ContactEntity],
        mainContact: ContactEntity,
        partialID: String,
        entityManager: EntityManager
    ) {
        // can't use NSBatchUpdateRequest because "A batch update cannot be used to alter relationships"
        // https://developer.apple.com/library/archive/featuredarticles/CoreData_Batch_Guide/BatchUpdates/BatchUpdates.html#//apple_ref/doc/uid/TP40016086-CH2-SW4
        let fetch = NSFetchRequest<BaseMessage>(entityName: "Message")
        fetch.predicate = NSPredicate(
            format: "isOwn == false && sender IN %@", duplicateContacts
        )
        
        do {
            let messages = try fetch.execute() as [BaseMessage]
            if !messages.isEmpty {
                for message in messages {
                    message.sender = mainContact
                }
                
                DDLogNotice(
                    "Updated \(messages.count) messages for \(partialID): sender set to ContactID-\(getCoreDataID(mainContact)) (previously set to a duplicate)"
                )
            }
            else {
                DDLogVerbose("No messages found where duplicates of \(partialID) are sender")
            }
        }
        catch {
            DDLogError("Error updating messages for \(partialID): could not execute fetch request")
        }
    }
    
    /// Iterate over all call history entries received from the given duplicates and delete them.
    /// This does not change call messages displayed in the chat.
    /// CallHistoryManager relies on the entries solely to display (or hide) missed calls from the past,
    /// hence it is safe to remove them.
    fileprivate func removeCallHistoryForDuplicates(
        duplicateContacts: [ContactEntity],
        partialID: String,
        entityManager: EntityManager
    ) {
        let fetch = NSFetchRequest<CallEntity>(entityName: "Call")
        fetch.predicate = NSPredicate(
            format: "contact IN %@", duplicateContacts
        )
        
        do {
            let calls = try fetch.execute() as [CallEntity]

            if !calls.isEmpty {
                for call in calls {
                    // call.contact = mainContact -> does not work bc. of missing @dynamic, see CallEntity.m
                    entityManager.entityDestroyer.delete(callEntity: call)
                }
                DDLogNotice(
                    "Deleted \(calls.count) calls for \(partialID): contact was set to a duplicate"
                )
            }
            else {
                DDLogVerbose("No calls found where duplicates of \(partialID) are contact")
            }
        }
        catch {
            DDLogError("Error updating calls for \(partialID): could not execute fetch request")
        }
    }

    /// Iterate over all messages that were rejected by duplicates and make sure main contact is listed as "rejector"
    /// instead
    fileprivate func updateGroupMembersToMainContact(
        duplicateContacts: [ContactEntity],
        mainContact: ContactEntity,
        partialID: String,
        entityManager: EntityManager
    ) {
        for duplicateContact in duplicateContacts {
            if let conversations = entityManager.entityFetcher
                .conversations(forMember: duplicateContact) as? [Conversation], !conversations.isEmpty {
                for conversation in conversations {
                    conversation.removeMembersObject(duplicateContact)
                    conversation.addMembersObject(mainContact)
                }
                
                DDLogNotice(
                    "Updated \(conversations.count) conversations for \(partialID): removed duplicate ContactID-\(getCoreDataID(duplicateContact)) from members and ensured ContactID-\(getCoreDataID(mainContact)) is a member"
                )
            }
            else {
                DDLogVerbose("No conversations found where duplicates of \(partialID) are members")
            }
        }
    }

    /// Iterate over all conversations where duplicates are group members and make sure main contact is member instead
    fileprivate func updateRejectedMessagesToMainContact(
        duplicateContacts: [ContactEntity],
        mainContact: ContactEntity,
        partialID: String,
        entityManager: EntityManager
    ) {
        var rejectedMessages = [BaseMessage]()
        
        for duplicateContact in duplicateContacts {
            if let rejectedByContact = duplicateContact.rejectedMessages {
                rejectedMessages.append(contentsOf: rejectedByContact)
            }
        }
                                  
        if !rejectedMessages.isEmpty {
            for message in rejectedMessages {
                for contact in duplicateContacts {
                    message.removeRejectedBy(contact)
                }
                message.addRejectedBy(mainContact)
            }
            
            DDLogNotice(
                "Updated \(rejectedMessages.count) messages for \(partialID): messages rejected by  ContactID-\(getCoreDataID(mainContact)) (previously set to a duplicate)"
            )
        }
        else {
            DDLogVerbose("No messages found that were rejected by duplicates of \(partialID)")
        }
    }

    /// Replace duplicate contacts by main contact and remove duplicate contacts if they
    /// have no 1:1 conversations
    ///
    /// Objects referencing the duplicates are updated to reference the main contact
    /// instead (exception: 1:1 conversations). The contact with the lowest core data
    /// ID is always considered to be the main contact.
    ///
    /// If, after the updates, the duplicates have 1:1 conversations, an alert dialog is shown listing
    /// them. In this case, the affected duplicates are not removed and the user has to re-run the
    /// cleanup after deleting the conversations manually.
    private func cleanupDuplicateContacts() {
        guard SettingsBundleHelper.safeMode, logContactStats() else {
            return
        }
        
        // prohibit contact cleanup when MD is active, because the cleanup code
        // may not synchronize changes across devices (and the MD scenario was not tested)
        guard !settingsStore.isMultiDeviceRegistered else {
            showMultiDeviceEnabledError = true
            return
        }
        
        let entityManager = BusinessInjector().entityManager

        entityManager.performAndWaitSave {
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
                
                // partially hide ID for privacy reasons
                let partialID = "****" + id.dropFirst(4)
                
                // sort to ensure that output ordering is stable across runs
                var sortedContactsToRemove = contacts.sorted { getCoreDataID($0) < getCoreDataID($1) }
                
                // we keep the first "main" contact (lowest internal core data ID) that belongs to
                // the current Threema ID
                let mainContact = sortedContactsToRemove.remove(at: 0)

                updateMessageSenderToMainContact(
                    duplicateContacts: sortedContactsToRemove,
                    mainContact: mainContact,
                    partialID: partialID,
                    entityManager: entityManager
                )
                updateRejectedMessagesToMainContact(
                    duplicateContacts: sortedContactsToRemove,
                    mainContact: mainContact,
                    partialID: partialID,
                    entityManager: entityManager
                )
                removeCallHistoryForDuplicates(
                    duplicateContacts: sortedContactsToRemove,
                    partialID: partialID,
                    entityManager: entityManager
                )
                updateGroupMembersToMainContact(
                    duplicateContacts: sortedContactsToRemove,
                    mainContact: mainContact,
                    partialID: partialID,
                    entityManager: entityManager
                )

                // no need to update ballot.participants:
                // - it is unused in existing code and will be removed in the future
                // - it is a "to many" relationship without inverse: it is stored in contact table as
                //   column Z2PARTICIPANTS and "disappears" automatically when deleting a duplicate contact
                
                for contact in sortedContactsToRemove {
                    let contactTotalMessageCount: Int = entityManager.entityFetcher.countMessages(forContact: contact)
                    let conversations = getAllConversations(contact: contact)
                    
                    if contactTotalMessageCount == 0, conversations.isEmpty {
                        removableContacts.append(contact)
                        DDLogNotice(
                            "Duplicate contact to be removed: ID=\(partialID), ContactID=\(getCoreDataID(contact))"
                        )
                    }
                    else {
                        DDLogNotice(
                            "Duplicate contact will not be removed because it is still in use: ID=\(partialID), ContactID=\(getCoreDataID(contact)), Contact#Msg=\(contactTotalMessageCount), #Conversations=\(conversations.count)"
                        )
                        unremovableContacts.append(contact)
                    }
                }
            }
            
            entityManager.cleanupUnusedContacts(removableContacts)
            DDLogNotice("\(removableContacts.count) duplicate contacts removed")
            
            guard unremovableContacts.isEmpty else {
                DDLogWarn(
                    "Contact cleanup incomplete: \(unremovableContacts.count) duplicates still have one-to-one chats."
                )
                
                let contactNames = unremovableContacts.map { "chat".localizedCapitalized + ": " + $0.displayName }
                    .joined(separator: "\n")

                alertMessage = String(
                    format: "settings_advanced_contacts_cleanup_still_used_error".localized,
                    removableContacts.count,
                    unremovableContacts.count,
                    contactNames
                )
                showDuplicatesInUseError = true
                
                return
            }
                        
            alertMessage = String(
                format: "settings_advanced_contacts_cleanup_unused_message"
                    .localized + "settings_advanced_contacts_cleanup_submit_logs".localized,
                removableContacts.count
            )
            showUnusedContactsCleanupDone = true
        }
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
