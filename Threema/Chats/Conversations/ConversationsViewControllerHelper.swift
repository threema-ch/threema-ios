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
import ThreemaFramework
import UIKit

class ConversationsViewControllerHelper {
    
    enum SingleFunction {
        case leaveDissolve
        case delete
    }

    /// Archives Multiple Conversations
    /// - Parameters:
    ///   - indexPaths: indexPaths of the selected Conversations
    ///   - fetchedResultsController: the FetchedResultsController handling the Conversations
    ///   - businessInjector: the BusinessInjector handling the Conversations
    ///   - completion: Closure that is executed after completion
    static func archiveConversations(
        at indexPaths: [IndexPath]?,
        fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>,
        businessInjector: BusinessInjectorProtocol,
        completion: @escaping () -> Void
    ) {
        
        guard let indexPaths = indexPaths else {
            return
        }
        // Sort and reverse in order to edit conversations from bottom to top in tableView, because the indexPaths are given in order of selection
        for indexPath in indexPaths.sorted().reversed() {
            guard let conversation = fetchedResultsController.object(at: indexPath) as? Conversation else {
                return
            }
            let utilities = ConversationActions(businessInjector: businessInjector)
            utilities.archive(conversation)
        }
        completion()
    }
    
    /// Unarchives Multiple Conversations
    /// - Parameters:
    ///   - indexPaths: indexPaths of the selected Conversations
    ///   - fetchedResultsController: the FetchedResultsController handling the Conversations
    ///   - businessInjector: the BusinessInjector handling the Conversations
    ///   - completion: Closure that is executed after completion
    static func unarchiveConversations(
        at indexPaths: [IndexPath]?,
        fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>,
        businessInjector: BusinessInjectorProtocol,
        completion: @escaping () -> Void
    ) {
        
        guard let indexPaths = indexPaths else {
            return
        }
        // Sort and reverse in order to edit conversations from bottom to top in tableView, because the indexPaths are given in order of selection
        for indexPath in indexPaths.sorted().reversed() {
            guard let conversation = fetchedResultsController.object(at: indexPath) as? Conversation else {
                return
            }
            let utilities = ConversationActions(businessInjector: businessInjector)
            utilities.unarchive(conversation)
        }
        completion()
    }
    
    /// Marks Multiple Conversations as Read
    /// - Parameters:
    ///   - indexPaths: indexPaths of the selected Conversations
    ///   - fetchedResultsController: the FetchedResultsController handling the Conversations
    ///   - businessInjector: the BusinessInjector handling the Conversations
    ///   - completion: Closure that is executed after completion
    static func readConversations(
        at indexPaths: [IndexPath]?,
        fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>,
        businessInjector: BusinessInjectorProtocol,
        completion: @escaping () -> Void
    ) {
        
        guard let indexPaths = indexPaths else {
            return
        }
        // Sort and reverse in order to edit conversations from bottom to top in tableView, because the indexPaths are given in order of selection
        for indexPath in indexPaths.sorted().reversed() {
            guard let conversation = fetchedResultsController.object(at: indexPath) as? Conversation else {
                return
            }
            let utilities = ConversationActions(businessInjector: businessInjector)
            utilities.read(conversation)
        }
        completion()
    }
    
    /// Marks Multiple Conversations as Unread
    /// - Parameters:
    ///   - indexPaths: indexPaths of the selected Conversations
    ///   - fetchedResultsController: the FetchedResultsController handling the Conversations
    ///   - businessInjector: the BusinessInjector handling the Conversations
    ///   - completion: Closure that is executed after completion
    static func unreadConversations(
        at indexPaths: [IndexPath]?,
        fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>,
        businessInjector: BusinessInjectorProtocol,
        completion: @escaping () -> Void
    ) {
        
        guard let indexPaths = indexPaths else {
            return
        }
        // Sort and reverse in order to edit conversations from bottom to top in tableView, because the indexPaths are given in order of selection
        for indexPath in indexPaths.sorted().reversed() {
            guard let conversation = fetchedResultsController.object(at: indexPath) as? Conversation else {
                return
            }
            let utilities = ConversationActions(businessInjector: businessInjector)
            utilities.unread(conversation)
        }
        completion()
    }

    /// Deletes a Conversation
    /// - Parameters:
    ///   - conversation: Conversation to be deleted
    ///   - group: Group to be deleted
    ///   - deleteHiddenContacts: True delete hidden contacts where member of the group
    ///   - entityManager: EntityManager to handle deletion
    private static func deleteConversation(
        conversation: Conversation,
        group: Group?,
        deleteHiddenContacts: Bool,
        entityManager: EntityManager
    ) {
        if let group = group {
            guard group.state != .active, group.state != .requestedSync else {
                return
            }
            
            SettingsStore.removeINInteractions(for: conversation.objectID)
        }

        MessageDraftStore.deleteDraft(for: conversation)
        WallpaperStore.shared.deleteWallpaper(for: conversation.objectID)
        ChatScrollPosition.shared.removeSavedPosition(for: conversation)

        var hiddenContacts = [String]()
        entityManager.performSyncBlockAndSafe {
            if deleteHiddenContacts {
                hiddenContacts = conversation.members.filter(\.isContactHidden).map(\.identity)
            }

            entityManager.entityDestroyer.deleteObject(object: conversation)
        }

        for identity in hiddenContacts {
            ContactStore.shared().deleteContact(identity: identity, entityManagerObject: entityManager)
        }

        let notificationManager = NotificationManager()
        notificationManager.updateUnreadMessagesCount()
        
        let info: Dictionary = [kKeyConversation: conversation]
        NotificationCenter.default.post(
            name: NSNotification.Name(kNotificationDeletedConversation),
            object: nil,
            userInfo: info
        )
    }
    
    /// Handles the Deletion Process when deleting a Conversation via SwipeGesture
    /// - Parameters:
    ///   - conversation: Conversation to Delete
    ///   - owner: ViewController to Display Alert
    ///   - entityManager: EntityManager Handling the Deletion
    ///   - handler: Handler to execute when action Completes
    static func handleDeletion(
        of conversation: Conversation,
        owner: UIViewController,
        cell: UITableViewCell? = nil,
        entityManager: EntityManager,
        singleFunction: SingleFunction? = nil,
        handler: @escaping (Bool) -> Void
    ) {
        var sheetTitle: String
        var sheetMessage: String?
        var actions = [UIAlertAction]()
        
        // differentiate between individual and group conversation
        if conversation.groupID == nil {
            // Conversation Delete Action
            if conversation.conversationCategory == .private {
                sheetTitle = BundleUtil.localizedString(forKey: "private_delete_info_alert_message")
            }
            else {
                sheetTitle = BundleUtil.localizedString(forKey: "conversation_delete_confirm")
            }
            sheetMessage = nil
            
            let singleConversationDeleteAction = createSingleConversationDeleteAlertAction(
                conversation: conversation,
                entityManager: entityManager,
                handler: handler
            )
            actions.append(singleConversationDeleteAction)
            
            UIAlertTemplate.showSheet(
                owner: owner,
                popOverSource: cell ?? owner.view,
                title: sheetTitle,
                message: sheetMessage,
                actions: actions
            )
        }
        else {
            // Group handling
            handleGroupDeletion(
                of: conversation,
                owner: owner,
                cell: cell,
                entityManager: entityManager,
                singleFunction: singleFunction,
                handler: handler
            )
        }
    }
    
    /// Handles the Deletion Process when deleting a group
    /// - Parameters:
    ///   - conversation: Conversation to Delete
    ///   - owner: ViewController to Display Alert
    ///   - cell: Cell to handle the popover action on iPads
    ///   - entityManager: EntityManager Handling the Deletion
    ///   - singleFunction: If function should only do a single function
    ///   - handler: Handler to execute when action Completes
    private static func handleGroupDeletion(
        of conversation: Conversation,
        owner: UIViewController,
        cell: UITableViewCell?,
        entityManager: EntityManager,
        singleFunction: SingleFunction?,
        handler: @escaping (Bool) -> Void
    ) {
        var sheetTitle: String
        var sheetMessage: String?
        var actions = [UIAlertAction]()
        
        guard let group = GroupManager().getGroup(conversation: conversation) else {
            return
        }
        
        // if self is member show option to leave and leave + delete,
        // or i'm creator to dissolve (delete) or otherwise just delete
        if group.isSelfMember {
            if let singleFunction = singleFunction {
                // Single function
                if group.isOwnGroup {
                    switch singleFunction {
                    case .delete:
                        sheetTitle = String.localizedStringWithFormat(
                            BundleUtil.localizedString(forKey: "group_dissolve_delete_sheet_title"),
                            conversation.groupName ?? ""
                        )
                        sheetMessage = BundleUtil.localizedString(forKey: "group_dissolve_delete_sheet_message")
                        let dissolveAndDeleteAction = createGroupConversationDissolveAndDeleteAlertAction(
                            group: group,
                            entityManager: entityManager,
                            handler: handler
                        )
                        actions.append(dissolveAndDeleteAction)
                    case .leaveDissolve:
                        sheetTitle = String.localizedStringWithFormat(
                            BundleUtil.localizedString(forKey: "group_dissolve_sheet_title"),
                            conversation.groupName ?? ""
                        )
                        sheetMessage = BundleUtil.localizedString(forKey: "group_dissolve_sheet_message")
                        let dissolveAction = createGroupConversationDissolveAlertAction(
                            group: group,
                            entityManager: entityManager,
                            handler: handler
                        )
                        actions.append(dissolveAction)
                    }
                }
                else {
                    switch singleFunction {
                    case .delete:
                        sheetTitle = String.localizedStringWithFormat(
                            BundleUtil.localizedString(forKey: "group_leave_delete_sheet_title"),
                            conversation.groupName ?? ""
                        )
                        sheetMessage = BundleUtil.localizedString(forKey: "group_leave_delete_sheet_message")
                        
                        let leaveAndDeleteAction = createGroupConversationLeaveAndDeleteAlertAction(
                            group: group,
                            entityManager: entityManager,
                            handler: handler
                        )
                        actions.append(leaveAndDeleteAction)
                    case .leaveDissolve:
                        sheetTitle = String.localizedStringWithFormat(
                            BundleUtil.localizedString(forKey: "group_leave_sheet_title"),
                            conversation.groupName ?? ""
                        )
                        sheetMessage = BundleUtil.localizedString(forKey: "group_leave_sheet_message")

                        let leaveAction = createGroupConversationLeaveAlertAction(
                            group: group,
                            handler: handler
                        )
                        actions.append(leaveAction)
                    }
                }
            }
            else {
                // Double function
                if group.isOwnGroup {
                    sheetTitle = String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "group_dissolve_delete_sheet_title"),
                        conversation.groupName ?? ""
                    )
                    sheetMessage = BundleUtil.localizedString(forKey: "group_dissolve_sheet_message")
                    let dissolveAction = createGroupConversationDissolveAlertAction(
                        group: group,
                        entityManager: entityManager,
                        handler: handler
                    )
                    actions.append(dissolveAction)
                    let dissolveAndDeleteAction = createGroupConversationDissolveAndDeleteAlertAction(
                        group: group,
                        entityManager: entityManager,
                        handler: handler
                    )
                    actions.append(dissolveAndDeleteAction)
                }
                else {
                    sheetTitle = String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "group_leave_delete_sheet_title"),
                        conversation.groupName ?? ""
                    )
                    sheetMessage = BundleUtil.localizedString(forKey: "group_leave_sheet_message")

                    let leaveAction = createGroupConversationLeaveAlertAction(
                        group: group,
                        handler: handler
                    )
                    actions.append(leaveAction)

                    let leaveAndDeleteAction = createGroupConversationLeaveAndDeleteAlertAction(
                        group: group,
                        entityManager: entityManager,
                        handler: handler
                    )
                    actions.append(leaveAndDeleteAction)
                }
            }
        }
        else {
            sheetTitle = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "group_delete_sheet_title"),
                conversation.groupName ?? ""
            )
            
            let deleteAction = createSingleConversationDeleteAlertAction(
                conversation: group.conversation,
                entityManager: entityManager,
                handler: handler
            )
            actions.append(deleteAction)
        }
        
        UIAlertTemplate.showSheet(
            owner: owner,
            popOverSource: cell ?? owner.view,
            title: sheetTitle,
            message: sheetMessage,
            actions: actions
        )
    }
       
    /// Creates a Conversation Delete Action for an Alert
    /// - Parameters:
    ///   - conversation: Conversation to be Deleted
    ///   - entityManager: EntityManager handling deletion
    ///   - handler: Handler to be called after Action is completed
    /// - Returns: UIAlertAction
    private static func createSingleConversationDeleteAlertAction(
        conversation: Conversation,
        entityManager: EntityManager,
        handler: @escaping (Bool) -> Void
    ) -> UIAlertAction {
        let deleteAction = UIAlertAction(
            title: BundleUtil.localizedString(forKey: conversation.isGroup() ? "group_delete_button" : "delete"),
            style: .destructive
        ) { _ in
            
            ConversationsViewControllerHelper.deleteConversation(
                conversation: conversation,
                group: nil,
                deleteHiddenContacts: true,
                entityManager: entityManager
            )
            handler(true)
        }
        return deleteAction
    }
    
    /// Creates a Group Conversation Leave Action for an Alert
    /// - Parameters:
    ///   - group: Group to be Left
    ///   - handler: Handler to be called after Action is completed
    /// - Returns: UIAlertAction
    private static func createGroupConversationLeaveAlertAction(
        group: Group,
        handler: @escaping (Bool) -> Void
    ) -> UIAlertAction {
        let leaveAction = UIAlertAction(
            title: BundleUtil.localizedString(forKey: "group_leave_button"),
            style: .destructive
        ) { _ in
            
            GroupManager().leave(groupID: group.groupID, creator: group.groupCreatorIdentity, toMembers: nil)
            handler(true)
        }
        return leaveAction
    }
    
    /// Creates a Group Conversation Leave & Delete Action for an Alert
    /// - Parameters:
    ///   - group: Group to be Left & Deleted
    ///   - entityManager: EntityManager handling the Deletion
    ///   - handler: Handler to be called after Action is completed
    /// - Returns: UIAlertAction
    private static func createGroupConversationLeaveAndDeleteAlertAction(
        group: Group,
        entityManager: EntityManager,
        handler: @escaping (Bool) -> Void
    ) -> UIAlertAction {
        let leaveAndDeleteAction = UIAlertAction(
            title: BundleUtil.localizedString(forKey: "group_leave_and_delete_button"),
            style: .destructive
        ) { _ in
            
            GroupManager().leave(groupID: group.groupID, creator: group.groupCreatorIdentity, toMembers: nil)
            ConversationsViewControllerHelper.deleteConversation(
                conversation: group.conversation,
                group: group,
                deleteHiddenContacts: false,
                entityManager: entityManager
            )
            handler(true)
        }
        return leaveAndDeleteAction
    }

    /// Creates a Group Conversation Dissolve Action for an Alert
    /// - Parameters:
    ///   - group: Group to be dissolve
    ///   - handler: Handler to be called after Action is completed
    /// - Returns: UIAlertAction
    private static func createGroupConversationDissolveAlertAction(
        group: Group,
        entityManager: EntityManager,
        handler: @escaping (Bool) -> Void
    ) -> UIAlertAction {
        let dissolveAction = UIAlertAction(
            title: BundleUtil.localizedString(forKey: "group_dissolve_button"),
            style: .destructive
        ) { _ in

            GroupManager(entityManager: entityManager).dissolve(groupID: group.groupID, to: nil)
            handler(true)
        }
        return dissolveAction
    }

    /// Creates a Group Conversation Dissolve & Delete Action for an Alert
    /// - Parameters:
    ///   - group: Group to be Dissolved & Deleted
    ///   - entityManager: EntityManager handling the Deletion
    ///   - handler: Handler to be called after Action is completed
    /// - Returns: UIAlertAction
    private static func createGroupConversationDissolveAndDeleteAlertAction(
        group: Group,
        entityManager: EntityManager,
        handler: @escaping (Bool) -> Void
    ) -> UIAlertAction {
        let dissolveAndDeleteAction = UIAlertAction(
            title: BundleUtil.localizedString(forKey: "group_dissolve_and_delete_button"),
            style: .destructive
        ) { _ in
            
            GroupManager(entityManager: entityManager).dissolve(groupID: group.groupID, to: nil)

            guard let conversation = entityManager.entityFetcher.conversation(
                for: group.groupIdentity.id,
                creator: group.groupIdentity.creator
            ) else {
                handler(false)
                return
            }
            ConversationsViewControllerHelper.deleteConversation(
                conversation: conversation,
                group: group,
                deleteHiddenContacts: false,
                entityManager: entityManager
            )
            handler(true)
        }
        return dissolveAndDeleteAction
    }

    /// Creates the Mark-Private ContextualAction for a TableView Swipe-Menu
    /// - Parameters:
    ///   - viewController: ViewController
    ///   - conversation: Conversation to be changed
    ///   - lockScreenWrapper: LockScreenWrapper Managing Passcode
    ///   - businessInjector: BusinessInjector handling changes of the Conversation
    /// - Returns: UIContextualAction for Swipe-Menu
    static func createPrivateAction(
        viewController: UIViewController,
        conversation: Conversation,
        lockScreenWrapper: LockScreen,
        businessInjector: BusinessInjectorProtocol
    ) -> UIContextualAction {
        
        let isPrivate = conversation.conversationCategory == .private
        
        let privateAction = UIContextualAction(style: .normal, title: nil) { _, _, handler in
            
            // Check if Passcode enabled, other wise display alert
            guard KKPasscodeLock.shared().isPasscodeRequired() else {
                ConversationsViewControllerHelper.presentNoPasscodeAlert(viewController: viewController)
                handler(true)
                return
            }
            
            // If private, show Passcode, else show alert with info
            if isPrivate {
                lockScreenWrapper.presentLockScreenView(
                    viewController: viewController,
                    enteredCorrectly: {
                        businessInjector.conversationStore.makeNotPrivate(conversation)
                    }
                )
            }
            else {
                ConversationsViewControllerHelper.showPrivateChatInfoAlert(
                    viewController: viewController,
                    conversation: conversation,
                    businessInjector: businessInjector
                )
            }
            handler(true)
        }
        
        let privateTitle: String
        
        if isPrivate {
            privateTitle = BundleUtil.localizedString(forKey: "remove_private")
            privateAction.image = BundleUtil.imageNamed("lock.slash.fill_regular.L")
        }
        else {
            privateTitle = BundleUtil.localizedString(forKey: "make_private")
            privateAction.image = BundleUtil.imageNamed("lock.fill_regular.L")
        }
        privateAction.title = privateTitle
        privateAction.accessibilityLabel = privateTitle
        privateAction.backgroundColor = Colors.gray
        
        return privateAction
    }
    
    /// Presents an Alert that tells the user to set a Passcode for PrivateChats
    /// - Parameter viewController: Controller where Alert is presented
    private static func presentNoPasscodeAlert(viewController: UIViewController) {
        UIAlertTemplate.showAlert(
            owner: viewController,
            title: BundleUtil.localizedString(forKey: "privateChat_alert_title"),
            message: BundleUtil.localizedString(forKey: "privateChat_code_alert_message"),
            titleOk: BundleUtil.localizedString(forKey: "privateChat_code_alert_confirm"),
            actionOk: { _ in
                // Open Passcode Modal
                guard let tabBarController = AppDelegate.getMainTabBarController() as? MainTabBarController else {
                    DDLogError("MainTabBarController unexpectedly found nil")
                    fatalError("MainTabBarController unexpectedly found nil")
                }
                
                let passCodeViewController = KKPasscodeSettingsViewController(style: .grouped)
                tabBarController.showModal(passCodeViewController)
            }
        )
    }
    
    /// Presents an Alert that tells the User he can hide PrivateChats
    /// - Parameters:
    ///   - viewController: Controller where Alert is presented
    ///   - conversation: Conversation to be marked Private
    ///   - businessInjector: BusinessInjector handling changes of the Conversation
    private static func showPrivateChatInfoAlert(
        viewController: UIViewController,
        conversation: Conversation,
        businessInjector: BusinessInjectorProtocol
    ) {
        UIAlertTemplate.showAlert(
            owner: viewController,
            title: BundleUtil.localizedString(forKey: "privateChat_set_alert_title"),
            message: BundleUtil.localizedString(forKey: "privateChat_set_alert_message"),
            titleOk: BundleUtil.localizedString(forKey: "make_private"),
            actionOk: { _ in
                businessInjector.conversationStore.makePrivate(conversation)
            }
        )
    }
}
