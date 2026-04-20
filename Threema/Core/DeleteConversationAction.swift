import ThreemaMacros
import UIKit

final class DeleteConversationAction: NSObject {
    
    // MARK: - Types
    
    @objc enum SingleFunction: Int {
        case double
        case leaveDissolve
        case delete
    }

    // MARK: - Private properties

    private static var identityStore = BusinessInjector.ui.myIdentityStore
    private static var chatScrollPositionStore = ChatScrollPosition.shared
    private static var wallpaperStore = WallpaperStore.shared
    private static var messageDraftStore = MessageDraftStore.shared
    private static var notificationManager = NotificationManager()
    private static var groupManager = BusinessInjector.ui.groupManager
    private static var entityManager = BusinessInjector.ui.entityManager
    
    // MARK: - Public actions

    /// Handles the Deletion Process when deleting a Conversation via SwipeGesture
    /// - Parameters:
    ///   - conversation: Conversation to Delete
    ///   - owner: ViewController to Display Alert
    ///   - handler: Handler to execute when action Completes
    @objc static func execute(
        for conversation: ConversationEntity,
        owner: UIViewController,
        cell: UITableViewCell? = nil,
        singleFunction: SingleFunction = .double,
        onCompletion: @escaping (Bool) -> Void
    ) {
        var sheetTitle: String
        var sheetMessage: String?
        var actions = [UIAlertAction]()
        let group = groupManager.getGroup(conversation: conversation)
        
        // Differentiate between individual and group conversation
        if conversation.groupID != nil {
            // Group handling
            handleGroupDeletion(
                for: conversation,
                group: group,
                owner: owner,
                cell: cell,
                singleFunction: singleFunction,
                handler: onCompletion
            )
        }
        else if let distributionList = conversation.distributionList {
            // Conversation Delete Action
            if conversation.conversationCategory == .private {
                sheetTitle = #localize("private_delete_info_alert_message")
            }
            else {
                sheetTitle = #localize("distribution_list_delete_sheet_title")
            }
            sheetMessage = nil
            
            let distributionListConversationDeleteAlertAction = createDistributionListDeleteAlertAction(
                distributionList: distributionList,
                handler: onCompletion
            )
            actions.append(distributionListConversationDeleteAlertAction)
            
            UIAlertTemplate.showSheet(
                owner: owner,
                popOverSource: cell ?? owner.view,
                title: sheetTitle,
                message: sheetMessage,
                actions: actions
            )
        }
        else if !conversation.isGroup {
            // Conversation Delete Action
            if conversation.conversationCategory == .private {
                sheetTitle = #localize("private_delete_info_alert_message")
            }
            else {
                sheetTitle = #localize("conversation_delete_confirm")
            }
            sheetMessage = nil
            
            let singleConversationDeleteAction = createSingleConversationDeleteAlertAction(
                conversation: conversation,
                handler: onCompletion
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
            handleGroupDeletion(
                for: conversation,
                group: group,
                owner: owner,
                cell: cell,
                singleFunction: singleFunction,
                handler: onCompletion
            )
        }
    }
    
    // MARK: - Helpers
    
    /// Handles the Deletion Process when deleting a group
    /// - Parameters:
    ///   - conversation: Conversation to Delete
    ///   - owner: ViewController to Display Alert
    ///   - cell: Cell to handle the popover action on iPads
    ///   - singleFunction: If function should only do a single function
    ///   - handler: Handler to execute when action Completes
    private static func handleGroupDeletion(
        for conversation: ConversationEntity,
        group: Group?,
        owner: UIViewController,
        cell: UITableViewCell?,
        singleFunction: SingleFunction,
        handler: @escaping (Bool) -> Void
    ) {
        var sheetTitle: String
        var sheetMessage: String?
        var actions = [UIAlertAction]()
        
        // If self is member show option to leave and leave + delete,
        // or i'm creator to dissolve (delete) or otherwise just delete
        if let group, group.isSelfMember {
            if group.isOwnGroup {
                switch singleFunction {
                case .delete:
                    sheetTitle = String.localizedStringWithFormat(
                        #localize("group_dissolve_delete_sheet_title"),
                        conversation.groupName ?? ""
                    )
                    sheetMessage = #localize("group_dissolve_delete_sheet_message")
                    let dissolveAndDeleteAction = createGroupConversationDissolveAndDeleteAlertAction(
                        group: group,
                        handler: handler
                    )
                    actions.append(dissolveAndDeleteAction)
                case .leaveDissolve:
                    sheetTitle = String.localizedStringWithFormat(
                        #localize("group_dissolve_sheet_title"),
                        conversation.groupName ?? ""
                    )
                    sheetMessage = #localize("group_dissolve_sheet_message")
                    let dissolveAction = createGroupConversationDissolveAlertAction(group: group, handler: handler)
                    actions.append(dissolveAction)
                case .double:
                    sheetTitle = String.localizedStringWithFormat(
                        #localize("group_dissolve_delete_sheet_title"),
                        conversation.groupName ?? ""
                    )
                    sheetMessage = #localize("group_dissolve_sheet_message")
                        
                    let dissolveAction = createGroupConversationDissolveAlertAction(
                        group: group,
                        handler: handler
                    )
                    actions.append(dissolveAction)
                        
                    let dissolveAndDeleteAction = createGroupConversationDissolveAndDeleteAlertAction(
                        group: group,
                        handler: handler
                    )
                    actions.append(dissolveAndDeleteAction)
                }
            }
            else {
                switch singleFunction {
                case .delete:
                    sheetTitle = String.localizedStringWithFormat(
                        #localize("group_leave_delete_sheet_title"),
                        conversation.groupName ?? ""
                    )
                    sheetMessage = #localize("group_leave_delete_sheet_message")
                        
                    let leaveAndDeleteAction = createGroupConversationLeaveAndDeleteAlertAction(
                        group: group,
                        handler: handler
                    )
                    actions.append(leaveAndDeleteAction)
                case .leaveDissolve:
                    sheetTitle = String.localizedStringWithFormat(
                        #localize("group_leave_sheet_title"),
                        conversation.groupName ?? ""
                    )
                    sheetMessage = #localize("group_leave_sheet_message")

                    let leaveAction = createGroupConversationLeaveAlertAction(group: group, handler: handler)
                    actions.append(leaveAction)
                case .double:
                    sheetTitle = String.localizedStringWithFormat(
                        #localize("group_leave_delete_sheet_title"),
                        conversation.groupName ?? ""
                    )
                    sheetMessage = #localize("group_leave_sheet_message")

                    let leaveAction = createGroupConversationLeaveAlertAction(group: group, handler: handler)
                    actions.append(leaveAction)

                    let leaveAndDeleteAction = createGroupConversationLeaveAndDeleteAlertAction(
                        group: group,
                        handler: handler
                    )
                    actions.append(leaveAndDeleteAction)
                }
            }
        }
        else {
            sheetTitle = String.localizedStringWithFormat(
                #localize("group_delete_sheet_title"),
                conversation.groupName ?? ""
            )
            
            let deleteAction = createSingleConversationDeleteAlertAction(conversation: conversation, handler: handler)
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
    ///   - handler: Handler to be called after Action is completed
    /// - Returns: UIAlertAction
    private static func createSingleConversationDeleteAlertAction(
        conversation: ConversationEntity,
        handler: @escaping (Bool) -> Void
    ) -> UIAlertAction {
        let deleteAction = UIAlertAction(
            title: #localize(conversation.isGroup ? "group_delete_button" : "delete"),
            style: .destructive
        ) { _ in
            deleteConversation(
                group: nil, conversation: conversation
            )
            handler(true)
        }
        return deleteAction
    }
    
    private static func createDistributionListDeleteAlertAction(
        distributionList: DistributionListEntity,
        handler: @escaping (Bool) -> Void
    ) -> UIAlertAction {
        let deleteAction = UIAlertAction(
            title: #localize("delete"),
            style: .destructive
        ) { _ in
            entityManager.performAndWaitSave {
                entityManager.entityDestroyer.delete(distributionListEntity: distributionList)
            }
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
            title: #localize("group_leave_button"),
            style: .destructive
        ) { _ in
            groupManager.leave(groupIdentity: group.groupIdentity, toMembers: nil)
            handler(true)
        }
        return leaveAction
    }
    
    /// Creates a Group Conversation Leave & Delete Action for an Alert
    /// - Parameters:
    ///   - group: Group to be Left & Deleted
    ///   - handler: Handler to be called after Action is completed
    /// - Returns: UIAlertAction
    private static func createGroupConversationLeaveAndDeleteAlertAction(
        group: Group,
        handler: @escaping (Bool) -> Void
    ) -> UIAlertAction {
        let leaveAndDeleteAction = UIAlertAction(
            title: #localize("group_leave_and_delete_button"),
            style: .destructive
        ) { _ in
            groupManager.leave(groupIdentity: group.groupIdentity, toMembers: nil)

            // The task added by the previous leave call takes care of deleting hidden contacts
            deleteConversation(
                group: group, conversation: group.conversation
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
        handler: @escaping (Bool) -> Void
    ) -> UIAlertAction {
        let dissolveAction = UIAlertAction(
            title: #localize("group_dissolve_button"),
            style: .destructive
        ) { _ in
            groupManager.dissolve(groupID: group.groupID, to: nil)
            handler(true)
        }
        return dissolveAction
    }

    /// Creates a Group Conversation Dissolve & Delete Action for an Alert
    /// - Parameters:
    ///   - group: Group to be Dissolved & Deleted
    ///   - handler: Handler to be called after Action is completed
    /// - Returns: UIAlertAction
    private static func createGroupConversationDissolveAndDeleteAlertAction(
        group: Group,
        handler: @escaping (Bool) -> Void
    ) -> UIAlertAction {
        let dissolveAndDeleteAction = UIAlertAction(
            title: #localize("group_dissolve_and_delete_button"),
            style: .destructive
        ) { _ in
            groupManager.dissolve(groupID: group.groupID, to: nil)

            guard let conversation = entityManager.entityFetcher.conversationEntity(
                for: group.groupIdentity, myIdentity: identityStore.identity
            ) else {
                handler(false)
                return
            }
            
            // Only the admin can dissolve a group, and since the admin can only ever add
            // non-hidden contacts as members, there's no need to delete hidden contacts here
            deleteConversation(
                group: group,
                conversation: conversation
            )
            handler(true)
        }
        return dissolveAndDeleteAction
    }
    
    private static func deleteConversation(
        group: Group?,
        conversation: ConversationEntity,
    ) {
        if let group {
            guard group.state != .active, group.state != .requestedSync else {
                return
            }
            
            SettingsStore.removeINInteractions(for: conversation.objectID)
        }

        messageDraftStore.deleteDraft(for: conversation)
        wallpaperStore.deleteWallpaper(for: conversation.objectID)
        chatScrollPositionStore.removeSavedPosition(for: conversation)

        entityManager.performAndWaitSave {
            entityManager.entityDestroyer.delete(conversation: conversation)
        }

        notificationManager.updateUnreadMessagesCount()
        
        let info: Dictionary = [kKeyConversation: conversation]
        NotificationCenter.default.post(
            name: NSNotification.Name(kNotificationDeletedConversation),
            object: nil,
            userInfo: info
        )
    }
}
