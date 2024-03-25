//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import Foundation
import ThreemaEssentials
import ThreemaProtocols

public protocol ConversationStoreProtocol {
    func pin(_ conversation: Conversation)
    func unpin(_ conversation: Conversation)
    func makePrivate(_ conversation: Conversation)
    func makeNotPrivate(_ conversation: Conversation)
    func archive(_ conversation: Conversation)
    func unarchive(_ conversation: Conversation)
}

protocol ConversationStoreInternalProtocol {
    func updateConversation(withContact syncContact: Sync_Contact)
    func updateConversation(withGroup syncGroup: Sync_Group)
}

public final class ConversationStore: NSObject, ConversationStoreInternalProtocol, ConversationStoreProtocol {
    private let userSettings: UserSettingsProtocol
    private let pushSettingManager: PushSettingManagerProtocol
    private let groupManager: GroupManagerProtocol
    private let entityManager: EntityManager
    private let taskManager: TaskManagerProtocol?

    required init(
        userSettings: UserSettingsProtocol,
        pushSettingManager: PushSettingManagerProtocol,
        groupManager: GroupManagerProtocol,
        entityManager: EntityManager,
        taskManager: TaskManagerProtocol?
    ) {
        self.userSettings = userSettings
        self.pushSettingManager = pushSettingManager
        self.groupManager = groupManager
        self.entityManager = entityManager
        self.taskManager = taskManager
    }

    @objc public func unmarkAllPrivateConversations() {
        entityManager.performSyncBlockAndSafe {
            for conversation in self.entityManager.entityFetcher.privateConversations() {
                guard let conversation = conversation as? Conversation else {
                    continue
                }
                self.makeNotPrivate(conversation)
            }
        }
        userSettings.hidePrivateChats = false
    }

    public func pin(_ conversation: Conversation) {
        guard conversation.conversationVisibility == .default else {
            return
        }
        saveAndSync(ConversationVisibility.pinned, of: conversation)
    }

    public func unpin(_ conversation: Conversation) {
        guard conversation.conversationVisibility == .pinned else {
            return
        }
        saveAndSync(ConversationVisibility.default, of: conversation)
    }

    public func makePrivate(_ conversation: Conversation) {
        guard conversation.conversationCategory != .private else {
            return
        }
        saveAndSync(ConversationCategory.private, of: conversation)
        
        if conversation.isGroup() {
            SettingsStore.removeINInteractions(for: conversation.objectID)
        }
        else if let contact = conversation.contact {
            SettingsStore.removeINInteractions(for: contact.objectID)
        }
    }

    public func makeNotPrivate(_ conversation: Conversation) {
        guard conversation.conversationCategory != .default else {
            return
        }
        saveAndSync(ConversationCategory.default, of: conversation)
    }

    public func archive(_ conversation: Conversation) {
        guard conversation.conversationVisibility != .archived else {
            return
        }
        saveAndSync(ConversationVisibility.archived, of: conversation)
    }

    public func unarchive(_ conversation: Conversation) {
        guard conversation.conversationVisibility == .archived else {
            return
        }
        saveAndSync(ConversationVisibility.default, of: conversation)
    }

    /// Update conversation (`Conversation.conversationCategory` and `Conversation.conversationVisibility`) of Contact.
    /// - Parameters:
    ///   - syncContact: Sync contact information
    func updateConversation(withContact syncContact: Sync_Contact) {
        guard let conversation = entityManager.entityFetcher.conversation(forIdentity: syncContact.identity) else {
            DDLogError("Conversation for contact (identity: \(syncContact.identity)) not found")
            return
        }

        if syncContact.hasConversationCategory,
           let category = ConversationCategory(rawValue: syncContact.conversationCategory.rawValue) {
            save(category, of: conversation)
        }

        if syncContact.hasConversationVisibility,
           let visibility = ConversationVisibility(rawValue: syncContact.conversationVisibility.rawValue) {
            save(visibility, of: conversation)
        }
    }

    /// Update conversation (`Conversation.conversationCategory` and `Conversation.conversationVisibility`) of Group.
    /// - Parameters:
    ///   - syncGroup: Sync group information
    func updateConversation(withGroup syncGroup: Sync_Group) {
        guard let groupIdentity = try? GroupIdentity(commonGroupIdentity: syncGroup.groupIdentity),
              let conversation = entityManager.entityFetcher.conversation(
                  for: groupIdentity.id,
                  creator: groupIdentity.creator.string
              ) else {
            DDLogError(
                "Group identity and conversation for group (\(syncGroup.groupIdentity)) not found"
            )
            return
        }

        if syncGroup.hasConversationCategory,
           let category = ConversationCategory(rawValue: syncGroup.conversationCategory.rawValue) {
            save(category, of: conversation)
        }

        if syncGroup.hasConversationVisibility,
           let visibility = ConversationVisibility(rawValue: syncGroup.conversationVisibility.rawValue) {
            save(visibility, of: conversation)
        }
    }

    // MARK: Private functions

    private func saveAndSync(_ attribute: some Any, of conversation: Conversation) {
        let identities = save(attribute, of: conversation)
        sync(attribute, contactIdentity: identities.contactIdentity, groupIdentity: identities.groupIdentity)
    }

    @discardableResult
    private func save(
        _ attribute: some Any,
        of conversation: Conversation
    ) -> (contactIdentity: String?, groupIdentity: GroupIdentity?) {
        assert(attribute is ConversationCategory || attribute is ConversationVisibility)

        var contactIdentity: String?
        var groupIdentity: GroupIdentity?

        entityManager.performSyncBlockAndSafe {
            if let conversation = self.entityManager.entityFetcher
                .existingObject(with: conversation.objectID) as? Conversation {
                // Save attribute on conversation
                if let conversationCategory = attribute as? ConversationCategory {
                    conversation.conversationCategory = conversationCategory
                }
                else if let conversationVisibility = attribute as? ConversationVisibility {
                    conversation.conversationVisibility = conversationVisibility
                }
                
                // Get identity of conversation
                if !conversation.isGroup() {
                    contactIdentity = conversation.contact?.identity
                }
                else {
                    if let group = self.groupManager.getGroup(conversation: conversation) {
                        groupIdentity = group.groupIdentity
                    }
                }
            }
        }

        return (contactIdentity, groupIdentity)
    }

    private func sync(_ attribute: some Any, contactIdentity: String?, groupIdentity: GroupIdentity?) {
        guard let taskManager else {
            DDLogWarn("Sync not possible, task manager is missing")
            return
        }

        assert(attribute is ConversationCategory || attribute is ConversationVisibility)

        // Sync conversation attribute
        if let contactIdentity {
            let syncer = MediatorSyncableContacts(
                userSettings,
                pushSettingManager,
                taskManager,
                entityManager
            )
            if let conversationCategory = attribute as? ConversationCategory {
                syncer.updateConversationCategory(identity: contactIdentity, value: conversationCategory)
            }
            else if let conversationVisibility = attribute as? ConversationVisibility {
                syncer.updateConversationVisibility(identity: contactIdentity, value: conversationVisibility)
            }
            syncer.syncAsync()
        }
        else if let groupIdentity {
            Task {
                let syncer = MediatorSyncableGroup(
                    userSettings,
                    pushSettingManager,
                    taskManager,
                    groupManager
                )
                if let conversationCategory = attribute as? ConversationCategory {
                    await syncer.update(identity: groupIdentity, conversationCategory: conversationCategory)
                }
                else if let conversationVisibility = attribute as? ConversationVisibility {
                    await syncer.update(identity: groupIdentity, conversationVisibility: conversationVisibility)
                }
                await syncer.sync(syncAction: .update)
            }
        }
    }
}
