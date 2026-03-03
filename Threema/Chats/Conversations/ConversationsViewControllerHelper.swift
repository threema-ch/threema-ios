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
import ThreemaFramework
import ThreemaMacros
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
        
        guard let indexPaths else {
            return
        }
        // Sort and reverse in order to edit conversations from bottom to top in tableView, because the indexPaths are
        // given in order of selection
        for indexPath in indexPaths.sorted().reversed() {
            guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
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
        
        guard let indexPaths else {
            return
        }
        // Sort and reverse in order to edit conversations from bottom to top in tableView, because the indexPaths are
        // given in order of selection
        for indexPath in indexPaths.sorted().reversed() {
            guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
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
        
        guard let indexPaths else {
            return
        }
        // Sort and reverse in order to edit conversations from bottom to top in tableView, because the indexPaths are
        // given in order of selection
        for indexPath in indexPaths.sorted().reversed() {
            guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
                return
            }
            Task {
                let utilities = ConversationActions(businessInjector: businessInjector)
                await utilities.read(conversation, isAppInBackground: AppDelegate.shared().isAppInBackground())
            }
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
        
        guard let indexPaths else {
            return
        }
        // Sort and reverse in order to edit conversations from bottom to top in tableView, because the indexPaths are
        // given in order of selection
        for indexPath in indexPaths.sorted().reversed() {
            guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
                return
            }
            let utilities = ConversationActions(businessInjector: businessInjector)
            utilities.unread(conversation)
        }
        completion()
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
        conversation: ConversationEntity,
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
            privateTitle = #localize("remove_private")
            privateAction.image = UIImage(systemName: "lock.slash.fill")
        }
        else {
            privateTitle = #localize("make_private")
            privateAction.image = UIImage(systemName: "lock.fill")
        }
        privateAction.title = privateTitle
        privateAction.accessibilityLabel = privateTitle
        privateAction.backgroundColor = .systemGray
        
        return privateAction
    }
    
    /// Presents an Alert that tells the user to set a Passcode for PrivateChats
    /// - Parameter viewController: Controller where Alert is presented
    private static func presentNoPasscodeAlert(viewController: UIViewController) {
        UIAlertTemplate.showAlert(
            owner: viewController,
            title: #localize("privateChat_alert_title"),
            message: #localize("privateChat_code_alert_message"),
            titleOk: #localize("privateChat_code_alert_confirm"),
            actionOk: { _ in
                // Open Passcode Modal
                guard let tabBarController = AppDelegate.getMainTabBarController() as? MainTabBarController else {
                    DDLogError("MainTabBarController unexpectedly found nil")
                    fatalError("MainTabBarController unexpectedly found nil")
                }
                
                let passCodeViewController = KKPasscodeSettingsViewController(style: .insetGrouped)
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
        conversation: ConversationEntity,
        businessInjector: BusinessInjectorProtocol
    ) {
        UIAlertTemplate.showAlert(
            owner: viewController,
            title: #localize("privateChat_set_alert_title"),
            message: #localize("privateChat_set_alert_message"),
            titleOk: #localize("make_private"),
            actionOk: { _ in
                businessInjector.conversationStore.makePrivate(conversation)
            }
        )
    }
}
