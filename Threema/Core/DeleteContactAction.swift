//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import ThreemaMacros

/// Delete action for a contact
///
/// Usage: Create an object and call `execute(in:of:completion:)` on it.
///
/// Alert flow:
/// ```
///                          ┌─────────────────┐
///                          │Is contact in any│
///                          │ existing group? │
///                          └─────────────────┘
///                                  │ │
///                       ┌────Yes───┘ └────No─────┐
///                       │                        │
///                       ▼                        ▼
///          ┌────────────────────────┐   ┌─────────────────┐
///          │       Show alert       │   │Does contact have│
///          │(depends on # groups and│   │an existing chat │
///          │  if shown in details)  │   │  conversation?  │
///          └────────────────────────┘   └─────────────────┘
///                                               │ │
///                                ┌──────Yes─────┘ └───────No───┐
///                                ▼                             ▼
///                          ┌───────────┐             ┌───────────────────┐
///                          │Can both be│             │Delete only contact│
///                          │ deleted?  │             │or also exclude (if│
///                          └───────────┘             │  it is linked)?   │
///                               │ │                  └───────────────────┘
///                     ┌───Yes───┘ └───No───┐                   │
///                     ▼                    ▼                   ▼
///         ┌──────────────────────┐     ┌──────┐             ┌─────┐
///         │       Delete.        │     │Cancel│             │Do it│
///         │   If it is linked:   │     └──────┘             └─────┘
///         │Should person be added│
///         │  to exclusion list?  │
///         └──────────┬─┬─────────┘
///                    │ │
///          ┌───Yes───┘ └───No───┐
///          │                    │
///          ▼                    ▼
///  ┌──────────────┐       ┌──────────┐
///  │    Add to    │       │Do nothing│
///  │exclusion list│       └──────────┘
///  └──────────────┘
/// ```
class DeleteContactAction: NSObject {
    
    /// Called at the end of execution
    /// - Parameter didDelete: `true` when the deletion happened, `false` otherwise
    typealias CompletionHandler = (_ didDelete: Bool) -> Void
    
    // MARK: Private properties
    
    /// Contact to be deleted with this action
    private let contact: ContactEntity
    
    private lazy var businessInjector = BusinessInjector.ui

    /// Create a new contact delete action
    ///
    /// - Parameter contact: Contact to be deleted
    @objc
    init(for contact: ContactEntity) {
        self.contact = contact
    }
    
    /// Execute deletion
    ///
    /// Depending on the state one or multiple sheets/alerts are shown to confirm the action.
    ///
    ///  - Parameter view: Origin view of action (used as anchor point for sheets)
    ///  - Parameter viewController: View controller to show sheets and alerts on
    ///  - Parameter completion: Called at the end of execution
    @objc
    func execute(
        in view: UIView,
        of viewController: UIViewController,
        completion: CompletionHandler? = nil
    ) {
        let isGroupMember = businessInjector.entityManager.entityFetcher.groupConversations(for: contact) != nil

        // Does contact have an existing 1:1 chat conversation?
        if let conversations = contact.conversations,
           !conversations.filter({ !$0.isGroup }).isEmpty {
            // Existing conversation. Can it also be deleted?
            showDeleteWithConversationSheet(
                in: view,
                of: viewController,
                with: contact.displayName,
                isGroupMember: isGroupMember,
                completion: completion
            )
        }
        else {
            // No existing conversation
            if contactCouldBeExcluded {
                // Delete contact only or also exclude?
                showDeleteWithExclusionSheet(
                    in: view,
                    of: viewController,
                    isGroupMember: isGroupMember,
                    completion: completion
                )
            }
            else {
                // Delete contact?
                showDeleteSheet(in: view, of: viewController, isGroupMember: isGroupMember, completion: completion)
            }
        }
    }
}

// MARK: - Private methods

extension DeleteContactAction {
    
    private func showDeleteWithConversationSheet(
        in view: UIView,
        of viewController: UIViewController,
        with contactName: String,
        isGroupMember: Bool,
        completion: CompletionHandler?
    ) {
        let deleteAlertAction = UIAlertAction(
            title: #localize("delete_contact_existing_conversation_button"),
            style: .destructive
        ) { _ in
            self.deleteContact(exclude: nil, completion: completion)
        }
        
        let sheetTitle =
            if isGroupMember {
                String.localizedStringWithFormat(
                    #localize("delete_contact_existing_conversation_is_group_member_title"),
                    contactName,
                    contactName
                )
            }
            else {
                String.localizedStringWithFormat(
                    #localize("delete_contact_existing_conversation_title"),
                    contactName
                )
            }

        UIAlertTemplate.showSheet(
            owner: viewController,
            popOverSource: view,
            title: sheetTitle,
            actions: [deleteAlertAction],
            cancelAction: { _ in completion?(false) }
        )
    }
    
    private func showDeleteWithExclusionSheet(
        in view: UIView,
        of viewController: UIViewController,
        isGroupMember: Bool,
        completion: CompletionHandler?
    ) {
        let localizedMessage =
            if isGroupMember {
                String.localizedStringWithFormat(
                    #localize("delete_contact_is_group_member_title_confirmation_with_exclusion_message"),
                    contact.displayName,
                    contact.displayName
                )
            }
            else {
                String.localizedStringWithFormat(
                    #localize("delete_contact_confirmation_with_exclusion_message"),
                    contact.displayName
                )
            }

        let deleteWithoutExclusionAction = UIAlertAction(
            title: #localize("delete_contact_button"),
            style: .destructive
        ) { _ in
            self.deleteContact(exclude: false, completion: completion)
        }
        
        let deleteWithExclusionAction = UIAlertAction(
            title: #localize("delete_contact_confirmation_with_exclusion_button"),
            style: .destructive
        ) { _ in
            self.deleteContact(exclude: true, completion: completion)
        }
        
        UIAlertTemplate.showSheet(
            owner: viewController,
            popOverSource: view,
            title: localizedMessage,
            message: #localize("exclude_deleted_id_message"),
            actions: [deleteWithoutExclusionAction, deleteWithExclusionAction],
            cancelAction: { _ in completion?(false) }
        )
    }
    
    private func showDeleteSheet(
        in view: UIView,
        of viewController: UIViewController,
        isGroupMember: Bool,
        completion: CompletionHandler?
    ) {
        let localizedMessage: String? =
            if isGroupMember {
                String.localizedStringWithFormat(
                    #localize("delete_contact_is_group_member_title"),
                    contact.displayName,
                    contact.displayName
                )
            }
            else {
                nil
            }

        let deleteAction = UIAlertAction(
            title: #localize("delete_contact_button"),
            style: .destructive
        ) { _ in
            self.deleteContact(exclude: false, completion: completion)
        }
        
        UIAlertTemplate.showSheet(
            owner: viewController,
            popOverSource: view,
            title: localizedMessage,
            actions: [deleteAction],
            cancelAction: { _ in completion?(false) }
        )
    }
    
    /// Delete contact
    ///
    /// - Parameter exclude: Add to exclusion list depending on flag, if it's `nil` the user is asked
    /// - Parameter completion: Completion handler
    private func deleteContact(exclude: Bool?, completion: CompletionHandler?) {
        
        // Temporarily store some contact information before it is destroyed
        var tempContactCouldBeExcluded = false
        var tempContactIdentity: String?
        var tempContactDisplayName = ""
        
        // Delete Contact
        
        // Remove left drafts
        if let conversations = contact.conversations {
            for conversation in conversations {
                MessageDraftStore.shared.deleteDraft(for: conversation)
                WallpaperStore.shared.deleteWallpaper(for: conversation.objectID)
            }
        }
        
        // Remove INInteractions
        SettingsStore.removeINInteractions(for: contact.objectID)
        
        // Delete any PFS sessions
        do {
            try businessInjector.dhSessionStore.deleteAllDHSessions(
                myIdentity: businessInjector.myIdentityStore.identity,
                peerIdentity: contact.identity
            )
        }
        catch {
            DDLogWarn("Cannot delete PFS sessions: \(error)")
        }
        
        // Remove contact & conversation
        businessInjector.entityManager.performAndWaitSave {
            tempContactCouldBeExcluded = self.contactCouldBeExcluded
            tempContactIdentity = self.contact.identity
            tempContactDisplayName = self.contact.displayName

            self.businessInjector.entityManager.entityDestroyer.deleteOneToOneConversation(for: self.contact)

            if let tempContactIdentity {
                Task {
                    await self.businessInjector.pushSettingManager
                        .delete(forContact: ThreemaIdentity(tempContactIdentity))
                }
            }
        }
        
        // Recalculate the unread count
        let notificationManager = NotificationManager()
        notificationManager.updateUnreadMessagesCount()
        
        guard let contactIdentity = tempContactIdentity else {
            DDLogWarn("Identity not captured during deletion")
            completion?(true)
            return
        }
                
        // Remove form profile picture receiver list
        UserSettings.shared()?.profilePictureContactList.removeAll { anyID in
            guard let id = anyID as? String else {
                return false
            }
            
            return id == contactIdentity
        }
        
        // Remove from profile picture request list
        ContactStore.shared().removeProfilePictureRequest(contactIdentity)
        
        // Send notification about deletion
        NotificationCenter.default.post(
            name: Notification.Name(kNotificationDeletedContact),
            object: nil,
            userInfo: [kKeyContact: contact]
        )
        
        ContactStore.shared().markContactAsDeleted(
            identity: contactIdentity,
            entityManagerObject: businessInjector.entityManager
        )

        // Handle any potential exclusion
        if let exclude {
            if exclude {
                excludeContact(with: contactIdentity)
            }
        }
        else if tempContactCouldBeExcluded {
            // This will only be called if no decision was taken so far
            // Should person be added to exclusion list?
            let localizedTitle = String.localizedStringWithFormat(
                #localize("exclude_deleted_id_title"),
                TargetManager.localizedAppName,
                tempContactDisplayName
            )
            
            UIAlertTemplate.showAlert(
                // There should always be a root view controller at this point
                owner: AppDelegate.shared().window.rootViewController!,
                title: localizedTitle,
                message: #localize("exclude_deleted_id_message"),
                titleOk: #localize("exclude_deleted_id_exclude_button"),
                actionOk: { _ in
                    self.excludeContact(with: contactIdentity)
                }
            )
        }
        
        completion?(true)
    }
    
    private var contactCouldBeExcluded: Bool {
        // swiftformat:disable:next acronyms
        let isLinked = contact.cnContactId != nil
        
        let contactIdentity = contact.identity
        let isAlreadyOnExclusionList = UserSettings.shared()?.syncExclusionList.contains(where: { anyID in
            guard let id = anyID as? String else {
                return false
            }
            
            return id == contactIdentity
        }) ?? false
        
        return isLinked && !isAlreadyOnExclusionList
    }
    
    private func excludeContact(with id: String) {
        UserSettings.shared()?.syncExclusionList.append(id)
    }
}
