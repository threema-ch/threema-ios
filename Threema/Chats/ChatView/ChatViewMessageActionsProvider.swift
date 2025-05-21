//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

enum ChatViewMessageActionsProvider {
 
    // MARK: - Message actions
    
    /// A section of message actions used to create context menus and `UIAccessibilityCustomAction`s
    public struct MessageActionsSection {
        enum SectionType {
            /// Show the first few symbols (~ 3 - 4) in horizontal order in iOS 16+ (see `UIMenu.ElementSize.small`).
            /// Otherwise rendered as `primary`
            case horizontalInline
            /// Show inline with a divider before and after
            case inline
            /// Show as collapsed menu with the provided title
            case submenu(title: String)
        }
        
        /// Type of section
        let sectionType: SectionType
        
        /// Actions in this section
        let actions: [MessageAction]
        
        public var contextMenu: UIMenu {
            switch sectionType {
            case .horizontalInline:
                let menu = UIMenu(options: .displayInline, children: actions.map(\.contextMenuAction))
                if #available(iOS 16.0, *) {
                    menu.preferredElementSize = .small
                }
                return menu
                
            case .inline:
                return UIMenu(options: .displayInline, children: actions.map(\.contextMenuAction))
                
            case let .submenu(title):
                return UIMenu(title: title, children: actions.map(\.contextMenuAction))
            }
        }
        
        public var accessibilityActions: [UIAccessibilityCustomAction] {
            actions.map(\.accessibilityAction)
        }
    }
    
    /// Intermediary struct used to create actions for context menus and `UIAccessibilityCustomAction`s
    public struct MessageAction {
        typealias Handler = () -> Void
        
        let title: String
        let image: UIImage?
        let attributes: UIMenuElement.Attributes
        let handler: Handler
        
        init(
            title: String,
            image: UIImage? = nil,
            attributes: UIMenuElement.Attributes = [],
            handler: @escaping Handler
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
    
    // MARK: - Prebuilt default action sections
    
    /// Default handler for most actions
    typealias DefaultHandler = () -> Void
    
    /// Returns a default set of actions depending on the message type and the provided optional handlers
    /// - Parameters:
    ///   - message: Target message for actions
    ///   - activityViewAnchor: Anchor view for activity
    ///   - popOverSource: Anchor point for delete confirmation
    ///   - markStarHandler: Called when add/remove star is tapped
    ///   - retryAndCancelHandler: Called when retry or cancel is tapped
    ///   - downloadHandler: Called when download is tapped
    ///   - quoteHandler: Called when quote is tapped
    ///   - editHandler: Called when edit is tapped
    ///   - saveHandler: Called when save is tapped
    ///   - copyHandler: Called when copy is tapped
    ///   - shareItems: Array of items to be shared with `UIActivityViewController`
    ///   - speakText: Text to be spoken when speak action is tapped
    ///   - detailsHandler: Called when details is tapped
    ///   - selectHandler: Called when select is tapped
    ///   - willDelete: Called when full (not remote) delete is selected and before the delete happens
    ///   - didDelete: Called when full (not remote) delete is selected and after the delete happened
    /// - Returns: A set of default actions sections
    public static func defaultActions(
        message: BaseMessageEntity,
        activityViewAnchor: UIView,
        popOverSource: UIView,
        markStarHandler: @escaping (BaseMessageEntity) -> Void?,
        retryAndCancelHandler: DefaultHandler? = nil,
        downloadHandler: DefaultHandler? = nil,
        quoteHandler: @escaping DefaultHandler,
        editHandler: DefaultHandler? = nil,
        saveHandler: DefaultHandler? = nil,
        copyHandler: @escaping DefaultHandler,
        shareItems: [Any],
        speakText: String,
        detailsHandler: @escaping DefaultHandler,
        selectHandler: @escaping DefaultHandler,
        willDelete: @escaping DefaultHandler,
        didDelete: @escaping DefaultHandler
    ) -> [MessageActionsSection] {
        
        // MARK: General actions
        
        var generalActions = [MessageAction]()
        
        generalActions.append(addStarMarkerAction(message: message, handler: markStarHandler))
        
        // File/media actions
        
        assert(
            !(message.showRetryAndCancelButton && message.hasPendingDownload),
            "Both should never be true at the same time"
        )
        
        if let retryAndCancelHandler, message.showRetryAndCancelButton {
            let retryAndCancel = retryAction(handler: retryAndCancelHandler)
            generalActions.append(retryAndCancel)
        }
        
        if let downloadHandler, message.hasPendingDownload {
            let download = downloadAction(handler: downloadHandler)
            generalActions.append(download)
        }
        
        // Quoting & editing
    
        if message.supportsQuoting {
            let quote = quoteAction(handler: quoteHandler)
            generalActions.append(quote)
        }
        
        if let editHandler, message.supportsEditing {
            let edit = editAction(handler: editHandler)
            generalActions.append(edit)
        }
        
        let generalActionsSection = MessageActionsSection(sectionType: .inline, actions: generalActions)
        
        // MARK: Share actions
        
        var shareActions = [MessageAction]()

        if let saveHandler, message.supportsSaving {
            let save = saveAction(handler: saveHandler)
            shareActions.append(save)
        }
        
        if message.supportsCopying {
            let copy = copyAction(handler: copyHandler)
            shareActions.append(copy)
        }
        
        if message.supportsForwarding {
            let forward = forwardAction(message: message)
            shareActions.append(forward)
        }
        
        if message.supportsSharing {
            let share = shareAction(view: activityViewAnchor, shareItems: shareItems)
            shareActions.append(share)
        }
        
        let shareActionsSection = MessageActionsSection(sectionType: .inline, actions: shareActions)
        
        // MARK: Speak actions
        
        var speakActions = [MessageAction]()
        
        // Add speak if it is enabled
        if UIAccessibility.isSpeakSelectionEnabled {
            let speak = speakAction(text: speakText)
            speakActions.append(speak)
        }
        
        let speakActionsSection = MessageActionsSection(sectionType: .inline, actions: speakActions)

        // MARK: More actions
                
        // These actions are always available
        let moreActions = defaultBasicActions(
            message: message,
            popOverSource: popOverSource,
            detailsHandler: detailsHandler,
            selectHandler: selectHandler,
            willDelete: willDelete,
            didDelete: didDelete
        )

        let moreActionsSection = MessageActionsSection(sectionType: .horizontalInline, actions: moreActions)
        
        // Return sections
        var actions = [
            generalActionsSection,
            shareActionsSection,
            moreActionsSection,
        ]
        
        if UIAccessibility.isSpeakSelectionEnabled {
            actions.insert(speakActionsSection, at: 2)
        }
        return actions
    }
    
    /// Default section of primary actions that should be supported by the provided message
    /// - Parameters:
    ///   - message: Message to create section for
    ///   - markStarHandler: Called when add/remove star is tapped
    /// - Returns: Section of default primary actions
    public static func defaultPrimaryActionsSection(
        message: BaseMessageEntity,
        markStarHandler: @escaping (BaseMessageEntity) -> Void?
    ) -> MessageActionsSection {
        var primaryActions = [MessageAction]()
        
        primaryActions.append(addStarMarkerAction(message: message, handler: markStarHandler))
        
        return MessageActionsSection(sectionType: .horizontalInline, actions: primaryActions)
    }
    
    /// Array of basic action that is supported by most message types
    /// - Parameters:
    ///   - message: Target message for actions
    ///   - popOverSource: Anchor point for delete confirmation
    ///   - detailsHandler: Called when details is tapped
    ///   - selectHandler: Called when select is tapped
    ///   - willDelete: Called when full (not remote) delete is selected and before the delete happens
    ///   - didDelete: Called when full (not remote) delete is selected and after the delete happened
    /// - Returns: Array of basic actions
    public static func defaultBasicActions(
        message: BaseMessageEntity,
        popOverSource: UIView,
        detailsHandler: @escaping DefaultHandler,
        selectHandler: @escaping DefaultHandler,
        willDelete: @escaping DefaultHandler,
        didDelete: @escaping DefaultHandler
    ) -> [MessageAction] {
        // Note: We return a set of actions instead of a section because we might use different section configurations
        // depending on the call side (e.g. horizontal or inline configuration)
    
        let details = detailsAction(handler: detailsHandler)
        let select = selectAction(handler: selectHandler)
        let delete = deleteAction(
            message: message,
            popOverSource: popOverSource,
            willDelete: willDelete,
            didDelete: didDelete
        )
        
        return [details, select, delete]
    }
    
    // MARK: - Actions (private helpers)
    
    private static func addStarMarkerAction(
        message: BaseMessageEntity,
        handler: @escaping (BaseMessageEntity) -> Void?
    ) -> MessageAction {
        let isStarred = message.messageMarkers?.star.boolValue ?? false
        let title = isStarred ? #localize("marker_action_remove_star") : #localize("marker_action_star")
        
        return MessageAction(
            title: title,
            image: message.messageMarkerStarImage
        ) {
            handler(message)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    // MARK: General actions
    
    private static let speechSynthesizerManager = SpeechSynthesizerManager()
    
    private static func quoteAction(handler: @escaping DefaultHandler) -> MessageAction {
        MessageAction(
            title: #localize("quote"),
            image: UIImage(systemName: "quote.bubble"),
            handler: handler
        )
    }
    
    /// Provides action that handles copying a message
    /// - Parameter handler: Closure to execute when action is selected
    /// - Returns: MessageAction
    private static func copyAction(handler: @escaping DefaultHandler) -> MessageAction {
        // We do not check for MDM values here because we allow copy on text messages but not on file messages
        MessageAction(
            title: #localize("copy"),
            image: UIImage(systemName: "doc.on.doc"),
            handler: handler
        )
    }
    
    /// Provides action that handles forwarding a message
    /// - Parameter message: Message to be forwarded
    /// - Returns: MessageAction
    private static func forwardAction(message: BaseMessageEntity) -> MessageAction {
        MessageAction(
            title: #localize("forward_menu"),
            image: UIImage(systemName: "arrowshape.turn.up.forward")
        ) {
            let cgPickerWrapper = ContactGroupPickerWrapper(message: message)
            cgPickerWrapper.showPicker()
        }
    }
    
    /// Provides action that handles sharing a message through the share sheet
    /// - Parameter shareItems: Array of items to be shared with UIActivityViewController
    /// - Returns: MessageAction
    private static func shareAction(view: UIView, shareItems: [Any]) -> MessageAction {
        MessageAction(
            title: #localize("share_menu"),
            image: UIImage(systemName: "square.and.arrow.up")
        ) {
            
            for item in shareItems {
                if (item as? BlobData) != nil {
                    guard !MDMSetup(setup: false).disableShareMedia() else {
                        DDLogWarn(
                            "[ChatViewMessageActionsProvider] Tried to share media, even though MDM disabled it."
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
    
    /// Provides action that speaks a message out loud
    /// - Parameter text: Text to be spoken when action is selected
    /// - Returns: MessageAction
    private static func speakAction(text: String) -> MessageAction {
        MessageAction(title: #localize("speak"), image: UIImage(systemName: "waveform")) {
            speechSynthesizerManager.speak(text)
        }
    }
    
    /// Provides action that handles displaying the details of a message
    /// - Parameter messageID: NSManagedObjectID of the message
    /// - Returns: MessageAction
    private static func detailsAction(handler: @escaping DefaultHandler) -> MessageAction {
        MessageAction(
            title: #localize("details"),
            image: UIImage(systemName: "info.circle"),
            handler: handler
        )
    }
    
    /// Provides action that starts selection mode in the table view the cell is displayed in
    /// - Parameter handler: Closure to execute when action is selected
    /// - Returns: MessageAction
    private static func selectAction(handler: @escaping DefaultHandler) -> MessageAction {
        MessageAction(
            title: #localize("chatview_contextmenu_select"),
            image: UIImage(systemName: "checkmark.circle"),
            handler: handler
        )
    }
    
    /// Provides action that starts editing the message of the cell
    /// - Parameter handler: Closure to execute when action is selected
    /// - Returns: MessageAction
    private static func editAction(handler: @escaping DefaultHandler) -> MessageAction {
        MessageAction(
            title: #localize("edit"),
            image: UIImage(resource: .threemaPencilBubbleLeft),
            handler: handler
        )
    }
    
    /// Provides action that handles deleting a message, also presents confirmation alert
    /// - Parameter message: Message to be deleted
    private static func deleteAction(
        message: BaseMessageEntity,
        popOverSource: UIView,
        willDelete: @escaping DefaultHandler,
        didDelete: @escaping DefaultHandler
    ) -> MessageAction {
        MessageAction(
            title: #localize("delete"),
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) {
            let businessInjector = BusinessInjector.ui
            var actions = [UIAlertAction]()
            actions.append(
                UIAlertAction(title: #localize("message_delete_for_me"), style: .destructive) { _ in
                    
                    willDelete()
                    
                    businessInjector.entityManager.performAndWaitSave {
                        businessInjector.entityManager.entityDestroyer.delete(baseMessage: message)
                        message.conversation.updateLastDisplayMessage(with: businessInjector.entityManager)
                    }
                    
                    didDelete()
                }
            )

            if message.supportsRemoteDeletion {
                actions.append(
                    UIAlertAction(
                        title: #localize("message_delete_for_everyone"),
                        style: .destructive
                    ) { _ in

                        var unsupportedContacts = FeatureMask.check(
                            message: message,
                            for: .deleteMessageSupport
                        ).unsupported
                        
                        // We filter out certain contacts in groups that will no receive the message anyway
                        if let group = businessInjector.groupManager.getGroup(conversation: message.conversation) {
                            var filteredUnsupportedContact = [Contact]()
                            
                            for unsupportedContact in unsupportedContacts {
                                // If the contact has a gateway ID and is the creator of
                                // the group the message is sent in…
                                if unsupportedContact.hasGatewayID,
                                   unsupportedContact.identity.string == group.groupCreatorIdentity {
                                    // … we only send the message to it, if it is a message storing gateway group.
                                    if group.isMessageStoringGatewayGroup {
                                        filteredUnsupportedContact.append(unsupportedContact)
                                    }
                                    else {
                                        continue
                                    }
                                }
                                
                                // All non gate way ID's are added anyways
                                filteredUnsupportedContact.append(unsupportedContact)
                            }
                            
                            unsupportedContacts = filteredUnsupportedContact
                        }
                        
                        let objectID = businessInjector.entityManager.performAndWait {
                            message.objectID
                        }

                        do {
                            try businessInjector.messageSender.sendDeleteMessage(
                                with: objectID,
                                receiversExcluded: unsupportedContacts
                            )

                            if !unsupportedContacts.isEmpty {
                                showDeleteMessageNotSentAlert(for: unsupportedContacts)
                            }
                        }
                        catch {
                            DDLogError("Delete message on this device and on chat partner failed: \(error)")
                        }
                    }
                )
            }

            UIAlertTemplate.showSheet(
                owner: AppDelegate.shared().currentTopViewController(),
                popOverSource: popOverSource,
                title: #localize("message_delete_confirm"),
                actions: actions
            )
        }
    }

    private static func showDeleteMessageNotSentAlert(for contacts: [Contact]) {
        let displayNames = contacts.map(\.displayName)
        let listFormatter = ListFormatter()
        var summary = ""

        if displayNames.count > 5 {
            var firstFive = displayNames.prefix(5)
            let count = displayNames.count - 5
            let countString = String.localizedStringWithFormat(
                #localize("delete_edit_message_not_sent_to_others"),
                count
            )
            firstFive.append(countString)
            if let totalSummary = listFormatter.string(from: Array(firstFive)) {
                summary =
                    "\(totalSummary)\n\(String.localizedStringWithFormat(#localize("delete_message_requirement"), TargetManager.appName))"
            }
        }
        else {
            if let shortsSummary = listFormatter.string(from: displayNames) {
                summary =
                    "\(shortsSummary)\n\(String.localizedStringWithFormat(#localize("delete_message_requirement"), TargetManager.appName))"
            }
        }

        let message = String.localizedStringWithFormat(#localize("delete_message_not_sent_to"), summary)
        UIAlertTemplate.showAlert(
            owner: AppDelegate.shared().currentTopViewController(),
            title: #localize("delete"),
            message: message
        )
    }

    // MARK: File actions

    private static func saveAction(handler: @escaping DefaultHandler) -> MessageAction {
        MessageAction(
            title: #localize("save"),
            image: UIImage(systemName: "square.and.arrow.down")
        ) {
            
            guard !MDMSetup(setup: false).disableShareMedia() else {
                DDLogError(
                    "[ChatViewMessageActionsProvider] Tried to save media, even though MDM disabled it."
                )
                return
            }
            
            handler()
        }
    }
    
    private static func downloadAction(handler: @escaping DefaultHandler) -> MessageAction {
        MessageAction(
            title: #localize("download"),
            image: UIImage(systemName: "arrow.down.circle"),
            handler: handler
        )
    }
    
    private static func retryAction(handler: @escaping DefaultHandler) -> MessageAction {
        // TODO: (IOS-4774) Check if it is retry or cancel
        MessageAction(
            title: #localize("retry"),
            image: UIImage(systemName: "arrow.clockwise"),
            handler: handler
        )
    }
}

extension UIResponder {
    fileprivate var parentViewController: UIViewController? {
        next as? UIViewController ?? next?.parentViewController
    }
}
