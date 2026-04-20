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
final class DeleteContactAction: NSObject {
    
    /// Called before the deletion starts after the user approves it
    typealias WillDeleteHandler = () -> Void
    
    /// Called at the end of execution
    /// - Parameter didDelete: `true` when the deletion happened (in this case `WillDeleteHandler` should also have been
    ///                        called before this), `false` otherwise
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
    /// - Parameters:
    ///   - view: Origin view of action (used as anchor point for sheets)
    ///   - viewController: View controller to show sheets and alerts on
    ///   - willDelete: Called before deletions starts if the deletion is not canceled
    ///   - completion: Called at the end of execution
    @objc
    func execute(
        in view: UIView,
        of viewController: UIViewController,
        willDelete: WillDeleteHandler? = nil,
        completion: CompletionHandler? = nil
    ) {
        let isGroupMember = businessInjector.entityManager.entityFetcher.conversationEntities(for: contact) != nil

        // Does contact have an existing 1:1 chat conversation?
        if let conversations = contact.conversations,
           !conversations.filter({ !$0.isGroup }).isEmpty {
            // Existing conversation. Can it also be deleted?
            showDeleteWithConversationSheet(
                in: view,
                of: viewController,
                with: contact.displayName,
                isGroupMember: isGroupMember,
                willDelete: willDelete,
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
                    willDelete: willDelete,
                    completion: completion
                )
            }
            else {
                // Delete contact?
                showDeleteSheet(
                    in: view,
                    of: viewController,
                    isGroupMember: isGroupMember,
                    willDelete: willDelete,
                    completion: completion
                )
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
        willDelete: WillDeleteHandler?,
        completion: CompletionHandler?
    ) {
        let deleteAlertAction = UIAlertAction(
            title: #localize("delete_contact_existing_conversation_button"),
            style: .destructive
        ) { _ in
            self.deleteContact(exclude: nil, willDelete: willDelete, completion: completion)
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
        willDelete: WillDeleteHandler?,
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
            self.deleteContact(exclude: false, willDelete: willDelete, completion: completion)
        }
        
        let deleteWithExclusionAction = UIAlertAction(
            title: #localize("delete_contact_confirmation_with_exclusion_button"),
            style: .destructive
        ) { _ in
            self.deleteContact(exclude: true, willDelete: willDelete, completion: completion)
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
        willDelete: WillDeleteHandler?,
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
            self.deleteContact(exclude: false, willDelete: willDelete, completion: completion)
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
    /// - Parameter willDelete: Called before deletion starts
    /// - Parameter completion: Completion handler
    private func deleteContact(
        exclude: Bool?,
        willDelete: WillDeleteHandler?,
        completion: CompletionHandler?
    ) {
        
        // Temporarily store some contact information before it is destroyed
        var tempContactCouldBeExcluded = false
        var tempContactIdentity: String?
        var tempContactDisplayName = ""
        
        // Delete Contact
        
        willDelete?()
        
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

            self.businessInjector.entityManager.entityDestroyer.deleteOneToOneConversation(
                for: self.contact
            ) { conversationEntity in
                // Remove draft & wallpaper before conversation is deleted
                MessageDraftStore.shared.deleteDraft(for: conversationEntity)
                WallpaperStore.shared.deleteWallpaper(for: conversationEntity.objectID)
            }

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
        let isLinked = contact.cnContactID != nil
        
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
        let settingsStore = businessInjector.settingsStore as! SettingsStore
        settingsStore.syncExclusionList.append(id)
    }
}
