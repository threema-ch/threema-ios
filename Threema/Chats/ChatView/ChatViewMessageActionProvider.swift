//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

struct ChatViewMessageActionProvider {
 
    // MARK: - MessageAction
    
    static let speechSynthesizerManager = SpeechSynthesizerManager()

    /// Intermediary struct used to create actions for ContextMenu- and UIAccessibilityCustomActions
    public struct MessageAction {
        
        var title: String
        var image: UIImage?
        var attributes: UIMenuElement.Attributes
        var handler: () -> Void
        
        init(
            title: String,
            image: UIImage? = nil,
            attributes: UIMenuElement.Attributes = [],
            handler: @escaping () -> Void
        ) {
            self.title = title
            self.image = image
            self.handler = handler
            self.attributes = attributes
        }
        
        public var contextMenuAction: UIAction {
            UIAction(title: title, image: image, attributes: attributes) { _ in
                handler()
            }
        }
        
        public var accessibilityAction: UIAccessibilityCustomAction {
            UIAccessibilityCustomAction(name: title, image: image) { _ in
                handler()
                return true
            }
        }
    }
    
    // MARK: - Prebuilt UIAction arrays
    
    /// Returns the default actions: quote, copy, forward, share, show details and delete
    /// - Parameters:
    ///   - message: Target message for actions
    ///   - speakText: Text to be spoken when speak action is selected
    ///   - shareItems: Array of items to be shared with UIActivityViewController
    ///   - activityViewAnchor: Anchor view for activity
    ///   - copyHandler: Closure to be executed when copy is tapped
    ///   - quoteHandler: Closure to be executed when quote is tapped
    ///   - detailsHandler: Closure to be executed when details is tapped
    ///   - editHandler: Closure to be executed when edit is tapped
    ///   - willDelete: Closure to be executed when delete is tapped and before the delete happens
    ///   - didDelete: Closure to be executed when delete is tapped and after the delete happened
    ///   - ackHandler: Closure to be executed when a reaction is tapped
    /// - Returns: Array of MessageActions
    public static func defaultActions(
        message: BaseMessage,
        speakText: String,
        shareItems: [Any],
        activityViewAnchor: UIView,
        copyHandler: @escaping () -> Void,
        quoteHandler: @escaping () -> Void,
        detailsHandler: @escaping () -> Void?,
        editHandler: @escaping () -> Void?,
        willDelete: @escaping () -> Void?,
        didDelete: @escaping () -> Void?,
        ackHandler: @escaping (BaseMessage, Bool) -> Void?
    ) -> [MessageAction] {
        
        var actions = [MessageAction]()
        
        let quote = quoteAction(handler: quoteHandler)
        let copy = copyAction(handler: copyHandler)
        let forward = forwardAction(message: message)
        let share = shareAction(view: activityViewAnchor, shareItems: shareItems)
        let details = detailsAction(handler: detailsHandler)
        let edit = editAction(handler: editHandler)
        let delete = deleteAction(
            message: message,
            willDelete: willDelete,
            didDelete: didDelete
        )
        
        if let fileMessageEntity = message as? BlobData {
            actions.append(contentsOf: [quote, details, edit, delete])
            
            if fileMessageEntity.isDataAvailable {
                actions.insert(forward, at: 1)
                
                if !MDMSetup(setup: false).disableShareMedia() {
                    actions.insert(copy, at: 1)
                    actions.insert(share, at: 3)
                }
            }
        }
        else {
            actions.append(contentsOf: [quote, copy, forward, share, details, edit, delete])
        }
        
        if message.isUserAckEnabled {
            let thumbsUp = thumbsUpAction(message: message, handler: ackHandler)
            actions.insert(thumbsUp, at: 0)

            let thumbsDown = thumbsDownAction(message: message, handler: ackHandler)
            actions.insert(thumbsDown, at: 1)
        }
        
        // Add speak if it is enabled
        if UIAccessibility.isSpeakSelectionEnabled {
            let speak = speakAction(text: speakText)
            if message.isUserAckEnabled {
                actions.insert(speak, at: 3)
            }
            else {
                actions.insert(speak, at: 1)
            }
        }
        
        return actions
    }
    
    // MARK: - Default actions

    public static func quoteAction(handler: @escaping () -> Void) -> MessageAction {
        MessageAction(title: BundleUtil.localizedString(forKey: "quote"), image: UIImage(systemName: "quote.bubble")) {
            handler()
        }
    }

    /// Provides action that speaks a message out loud
    /// - Parameter text: Text to be spoken when action is selected
    /// - Returns: MessageAction
    public static func speakAction(text: String) -> MessageAction {
        MessageAction(title: BundleUtil.localizedString(forKey: "speak"), image: UIImage(systemName: "waveform")) {
            speechSynthesizerManager.speak(text)
        }
    }
    
    /// Provides action that handles copying a message
    /// - Parameter handler: Closure to execute when action is selected
    /// - Returns: MessageAction
    public static func copyAction(handler: @escaping () -> Void) -> MessageAction {
        MessageAction(title: BundleUtil.localizedString(forKey: "copy"), image: UIImage(systemName: "doc.on.doc")) {
            // We do not check for MDM values here because we allow copy on text messages but not on file messages
            handler()
        }
    }
    
    /// Provides action that handles forwarding a message
    /// - Parameter message: Message to be forwarded
    /// - Returns: MessageAction
    public static func forwardAction(message: BaseMessage) -> MessageAction {
        MessageAction(
            title: BundleUtil.localizedString(forKey: "forward") + "…",
            image: UIImage(systemName: "arrowshape.turn.up.forward")
        ) {
            let cgPickerWrapper = ContactGroupPickerWrapper(message: message)
            cgPickerWrapper.showPicker()
        }
    }
    
    /// Provides action that handles sharing a message through the share sheet
    /// - Parameter shareItems: Array of items to be shared with UIActivityViewController
    /// - Returns: MessageAction
    public static func shareAction(view: UIView, shareItems: [Any]) -> MessageAction {
        MessageAction(
            title: BundleUtil.localizedString(forKey: "share") + "…",
            image: UIImage(systemName: "square.and.arrow.up")
        ) {
            
            for item in shareItems {
                if (item as? BlobData) != nil {
                    guard !MDMSetup(setup: false).disableShareMedia() else {
                        DDLogWarn(
                            "[ChatViewMessageActionProvider] Tried to share media, even if MDM disabled it."
                        )
                        return
                    }
                }
            }
            
            let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
            
            // Show
            ModalPresenter.present(
                activityVC,
                on: view.parentViewController,
                from: view.frame,
                in: view
            )
        }
    }
    
    /// Provides action that handles displaying the details of a message
    /// - Parameter messageID: NSManagedObjectID of the message
    /// - Returns: MessageAction
    public static func detailsAction(handler: @escaping () -> Void?) -> MessageAction {
        MessageAction(
            title: BundleUtil.localizedString(forKey: "details"),
            image: UIImage(systemName: "info.circle")
        ) {
            handler()
        }
    }
    
    /// Provides action that starts edit mode in the table view the cell is displayed in
    /// - Parameter handler: Closure to execute when action is selected
    /// - Returns: MessageAction
    public static func editAction(handler: @escaping () -> Void?) -> MessageAction {
        MessageAction(
            title: BundleUtil.localizedString(forKey: "chatview_contextmenu_select"),
            image: UIImage(systemName: "ellipsis.circle")
        ) {
            handler()
        }
    }
    
    /// Provides action that handles deleting a message, also presents confirmation alert
    /// - Parameter message: Message to be deleted
    public static func deleteAction(
        message: BaseMessage,
        willDelete: @escaping () -> Void?,
        didDelete: @escaping () -> Void?
    ) -> MessageAction {
        MessageAction(
            title: BundleUtil.localizedString(forKey: "delete"),
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) {
            // Show alert
            UIAlertTemplate.showDestructiveAlert(
                owner: AppDelegate.shared().currentTopViewController(),
                title: BundleUtil.localizedString(forKey: "messages_delete_selected_confirm"),
                message: nil,
                titleDestructive: BundleUtil.localizedString(forKey: "delete")
            ) { _ in
                
                willDelete()
                
                // Delete
                let entityManager = EntityManager()
                entityManager.performSyncBlockAndSafe {
                    entityManager.entityDestroyer.deleteObject(object: message)
                    message.conversation.updateLastMessage(with: entityManager)
                }
                
                didDelete()
            }
        }
    }
    
    // MARK: - Vote actions
    
    private static func thumbsUpAction(
        message: BaseMessage,
        handler: @escaping (BaseMessage, Bool) -> Void?
    ) -> MessageAction {
        var image: UIImage?
        
        if message.isGroupMessage {
            image = message.groupReactionsThumbsUpImage
        }
        else {
            image = message.userThumbsUpImage
        }
                
        return MessageAction(
            title: BundleUtil.localizedString(forKey: "acknowledge"),
            image: image
        ) {
            handler(message, true)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    private static func thumbsDownAction(
        message: BaseMessage,
        handler: @escaping (BaseMessage, Bool) -> Void?
    ) -> MessageAction {
        var image: UIImage?
        
        if message.isGroupMessage {
            image = message.groupReactionsThumbsDownImage
        }
        else {
            image = message.userThumbsDownImage
        }
                
        return MessageAction(
            title: BundleUtil.localizedString(forKey: "decline"),
            image: image
        ) {
            handler(message, false)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    // MARK: - File actions

    public static func saveAction(handler: @escaping () -> Void) -> MessageAction {
        MessageAction(
            title: BundleUtil.localizedString(forKey: "save"),
            image: UIImage(systemName: "square.and.arrow.down")
        ) {
            
            guard !MDMSetup(setup: false).disableShareMedia() else {
                fatalError()
            }
            
            handler()
        }
    }
    
    public static func downloadAction(handler: @escaping () -> Void) -> MessageAction {
        MessageAction(
            title: BundleUtil.localizedString(forKey: "download"),
            image: UIImage(systemName: "arrow.down.circle")
        ) {
            handler()
        }
    }
    
    public static func retryAction(handler: @escaping () -> Void) -> MessageAction {
        MessageAction(
            title: BundleUtil.localizedString(forKey: "retry"),
            image: UIImage(systemName: "arrow.clockwise")
        ) {
            handler()
        }
    }
}

extension UIResponder {
    fileprivate var parentViewController: UIViewController? {
        next as? UIViewController ?? next?.parentViewController
    }
}
