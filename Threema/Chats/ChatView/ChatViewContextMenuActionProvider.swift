//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import Foundation
import ThreemaFramework
import UIKit

struct ChatViewContextMenuActionProvider {
 
    // MARK: - Prebuilt UIAction arrays
    
    /// Returns the default actions: quote, copy, forward, share, show details and delete
    /// - Parameters:
    ///   - message: Target message for actions
    ///   - speakText: Text to be spoken when speak action is selected
    ///   - shareItems: Array of items to be shared with UIActivityViewController
    ///   - copyHandler: Closure to be executed when copy is tapped
    ///   - quoteHandler: Closure to be executed when quote is tapped
    /// - Returns: Array of UIActions
    public static func defaultActions(
        message: BaseMessage,
        speakText: String,
        shareItems: [Any],
        copyHandler: @escaping () -> Void,
        quoteHandler: @escaping () -> Void
    ) -> [UIAction] {
        
        var actions = [UIAction]()
        
        // Add thumbs actions for received messages
        if !message.isOwnMessage, !message.conversation.isGroup() {
            let thumbsUp = thumbsUpAction(message: message)
            let thumbsDown = thumbsDownAction(message: message)
            actions.append(contentsOf: [thumbsUp, thumbsDown])
        }
        
        let quote = quoteAction(handler: quoteHandler)
        actions.append(quote)
        
        // Add speak if it is enabled
        if UIAccessibility.isSpeakSelectionEnabled {
            let speak = speakAction(text: speakText)
            actions.append(speak)
        }
        
        let copy = copyAction(handler: copyHandler)
        let forward = forwardAction(message: message)
        let share = shareAction(shareItems: shareItems)
        let details = detailsAction(message: message)
        let delete = deleteAction(message: message)
        
        // TODO: IOS-2601: Re-add details and quote and move speak action
        actions.append(contentsOf: [copy, forward, share, delete])
        
        return actions
    }
    
    // MARK: - Default actions

    // TODO: IOS-2601
    public static func quoteAction(handler: @escaping () -> Void) -> UIAction {
        UIAction(title: BundleUtil.localizedString(forKey: "quote"), image: UIImage(systemName: "quote.bubble")) { _ in
            handler()
        }
    }

    /// Provides action that speaks a message out loud
    /// - Parameter text: Text to be spoken when action is selected
    /// - Returns: UIAction
    public static func speakAction(text: String) -> UIAction {
        UIAction(title: BundleUtil.localizedString(forKey: "speak"), image: UIImage(systemName: "waveform")) { _ in
            let utterance = AVSpeechUtterance(string: text)
            let synth = AVSpeechSynthesizer()
            synth.speak(utterance)
        }
    }
    
    /// Provides action that handles copying a message
    /// - Parameter handler: Closure to execute when action is selected
    /// - Returns: UIAction
    public static func copyAction(handler: @escaping () -> Void) -> UIAction {
        UIAction(title: BundleUtil.localizedString(forKey: "copy"), image: UIImage(systemName: "doc.on.doc")) { _ in
            handler()
        }
    }
    
    /// Provides action that handles forwarding a message
    /// - Parameter message: Message to be forwarded
    /// - Returns: UIAction
    public static func forwardAction(message: BaseMessage) -> UIAction {
        UIAction(
            title: BundleUtil.localizedString(forKey: "forward"),
            image: UIImage(systemName: "arrowshape.turn.up.forward")
        ) { _ in
            let cgPickerWrapper = ContactGroupPickerWrapper(message: message)
            cgPickerWrapper.showPicker()
        }
    }
    
    /// Provides action that handles sharing a message through the share sheet
    /// - Parameter shareItems: Array of items to be shared with UIActivityViewController
    /// - Returns: UIAction
    public static func shareAction(shareItems: [Any]) -> UIAction {
        UIAction(
            title: BundleUtil.localizedString(forKey: "share"),
            image: UIImage(systemName: "square.and.arrow.up")
        ) { _ in
            
            let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
            
            let rootView = AppDelegate.shared().currentTopViewController()
            rootView?.present(activityVC, animated: true)
        }
    }
    
    // TODO: IOS-2601
    public static func detailsAction(message: BaseMessage) -> UIAction {
        UIAction(title: BundleUtil.localizedString(forKey: "details"), image: UIImage(systemName: "info.circle")) { _ in
            // TODO: IOS-2414 Show new detail view
            print("")
        }
    }
    
    /// Provides action that handles deleting a message, also presents confirmation alert
    /// - Parameter message: Message to be deleted
    /// - Returns: UIAction
    public static func deleteAction(message: BaseMessage) -> UIAction {
        UIAction(
            title: BundleUtil.localizedString(forKey: "delete"),
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { _ in
            
            // Show alert
            UIAlertTemplate.showDestructiveAlert(
                owner: AppDelegate.shared().currentTopViewController(),
                title: BundleUtil.localizedString(forKey: "messages_delete_selected_confirm"),
                message: nil,
                titleDestructive: BundleUtil.localizedString(forKey: "Delete")
            ) { _ in
                
                // Delete
                let entityManager = EntityManager()
                entityManager.performSyncBlockAndSafe {
                    entityManager.entityDestroyer.deleteObject(object: message)
                }
            }
        }
    }
    
    // MARK: - Vote actions
    
    private static func thumbsUpAction(message: BaseMessage) -> UIAction {
        UIAction(
            title: BundleUtil.localizedString(forKey: "acknowledge"),
            image: UIImage(systemName: "hand.thumbsup")?
                .withTintColor(Colors.thumbUp, renderingMode: .alwaysOriginal)
        ) { _ in
            sendAck(message: message, ack: true)
        }
    }
    
    private static func thumbsDownAction(message: BaseMessage) -> UIAction {
        UIAction(
            title: BundleUtil.localizedString(forKey: "decline"),
            image: UIImage(systemName: "hand.thumbsdown")?
                .withTintColor(Colors.thumbDown, renderingMode: .alwaysOriginal)
        ) { _ in
            sendAck(message: message, ack: false)
        }
    }
    
    // MARK: - File actions

    // TODO: IOS-2601
    public static func saveAction(handler: @escaping () -> Void) -> UIAction {
        UIAction(
            title: BundleUtil.localizedString(forKey: "save"),
            image: UIImage(systemName: "square.and.arrow.down")
        ) { _ in
            handler()
        }
    }
    
    // MARK: - Helpers

    ///  Processes sending thumbsUp or thumbsDown
    private static func sendAck(message: BaseMessage, ack: Bool) {
        let entityManager = EntityManager()
        
        guard let entityMessage = entityManager.entityFetcher.existingObject(with: message.objectID) as? BaseMessage,
              let conversation = entityMessage.conversation else {
            return
        }
        
        let groupManager = GroupManager(entityManager: entityManager)
        let group = groupManager.getGroup(conversation: conversation)
        var contact: Contact?
        
        if conversation.isGroup() {
            if let groupDeliveryReceipts = entityMessage.groupDeliveryReceipts,
               !groupDeliveryReceipts.isEmpty,
               let gdr = entityMessage.reaction(for: MyIdentityStore.shared().identity),
               gdr.deliveryReceiptType() == (ack ? .userAcknowledgment : .userDeclined) {
                return
            }
        }
        else {
            guard let c = conversation.contact else {
                return
            }
            contact = c
            // Only send changed acks
            if entityMessage.userackDate != nil, let currentAck = entityMessage.userack, currentAck.boolValue == ack {
                return
            }
        }
        
        if ack {
            MessageSender.sendUserAck(
                forMessages: [message],
                toIdentity: contact?.identity,
                group: group,
                onCompletion: {
                    entityManager.performSyncBlockAndSafe {
                        if conversation.isGroup() {
                            let groupDeliveryReceipt = GroupDeliveryReceipt(
                                identity: MyIdentityStore.shared().identity,
                                deliveryReceiptType: .userAcknowledgment,
                                date: Date()
                            )
                            message.add(groupDeliveryReceipt: groupDeliveryReceipt)
                        }
                        else {
                            message.userack = NSNumber(booleanLiteral: ack)
                            message.userackDate = Date()
                        }
                    }
                }
            )
        }
        else {
            MessageSender.sendUserDecline(
                forMessages: [message],
                toIdentity: contact?.identity,
                group: group,
                onCompletion: {
                    entityManager.performSyncBlockAndSafe {
                        if conversation.isGroup() {
                            let groupDeliveryReceipt = GroupDeliveryReceipt(
                                identity: MyIdentityStore.shared().identity,
                                deliveryReceiptType: .userDeclined,
                                date: Date()
                            )
                            message.add(groupDeliveryReceipt: groupDeliveryReceipt)
                        }
                        else {
                            message.userack = NSNumber(booleanLiteral: ack)
                            message.userackDate = Date()
                        }
                    }
                }
            )
        }
    }
}
