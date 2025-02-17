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

import AudioToolbox
import CocoaLumberjackSwift
import GroupCalls
import SwiftProtobuf
import SwiftUI
import ThreemaFramework
import ThreemaMacros
import ThreemaProtocols
import UIKit
import VisionKit

protocol ChatBarCoordinatorDelegate: AnyObject {
    func didDismissQuoteView()
    var userInterfaceMode: ChatViewController.UserInterfaceMode { get }
}

final class ChatBarCoordinator {

    // MARK: - Public properties

    lazy var chatBarContainerView: ChatBarContainerView = {
        let chatBarContainerView = ChatBarContainerView()
        chatBarContainerView.add(chatBar)
        
        return chatBarContainerView
    }()
    
    /// chatBar should only be used in extensions of ChatBarCoordinator
    lazy var chatBar: ChatBarView = {
        let chatBarView = ChatBarView(
            conversation: conversation,
            mentionsDelegate: self,
            precomposedText: precomposedText
        )
        chatBarView.chatBarViewDelegate = self

        return chatBarView
    }()
    
    var isRecording = false
    
    // MARK: - Private properties
    
    private var conversation: ConversationEntity
    private var messageToEdit: EditedMessage? {
        didSet {
            if let baseMessage = messageToEdit as? BaseMessage {
                editedMessageDeletionObserver = baseMessage.observe(\.willBeDeleted) { [weak self] baseMessage, _ in
                    if baseMessage.willBeDeleted {
                        self?.removeEditedMessageView()
                    }
                }
            }
            else {
                editedMessageDeletionObserver?.invalidate()
                editedMessageDeletionObserver = nil
            }
        }
    }

    private var quoteMessage: QuoteMessage? {
        didSet {
            if let baseMessage = quoteMessage as? BaseMessage {
                quotedMessageDeletionObserver = baseMessage.observe(\.willBeDeleted) { [weak self] baseMessage, _ in
                    if baseMessage.willBeDeleted {
                        self?.removeQuoteView()
                    }
                }
            }
            else {
                quotedMessageDeletionObserver?.invalidate()
                quotedMessageDeletionObserver = nil
            }
        }
    }

    private var mentionsTableViewController: MentionsTableViewController?
    private weak var chatViewController: ChatViewController?
    private weak var chatViewTableViewVoiceMessageCellDelegate: ChatViewTableViewVoiceMessageCellDelegate?
    private weak var chatBarCoordinatorDelegate: ChatBarCoordinatorDelegate?

    private let businessInjector: BusinessInjectorProtocol
    private var editedMessageDeletionObserver: NSKeyValueObservation?
    private var quotedMessageDeletionObserver: NSKeyValueObservation?
    
    private lazy var messagePermission = MessagePermission(
        myIdentityStore: MyIdentityStore.shared(),
        userSettings: UserSettings.shared(),
        groupManager: businessInjector.groupManager,
        entityManager: businessInjector.entityManager
    )
    
    private lazy var sentMessageSoundID: SystemSoundID? = {
        guard let soundURL = BundleUtil.url(forResource: "sent_message", withExtension: "caf") else {
            return nil
        }
        
        var sentMessageSoundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(soundURL as CFURL, &sentMessageSoundID)
        return sentMessageSoundID
    }()
    
    private var chatViewActionsHelper: ChatViewControllerActionsHelper
    
    private var mentionsVisible = false
    
    private var precomposedText: String?
    
    /// Keeps track of the last sent typing state
    private var lastTypingIndicatorState = false
    
    // MARK: - Lifecycle
    
    init(
        conversation: ConversationEntity,
        chatViewControllerActionsHelper: ChatViewControllerActionsHelper,
        chatViewController: ChatViewController,
        chatBarCoordinatorDelegate: ChatBarCoordinatorDelegate?,
        chatViewTableViewVoiceMessageCellDelegate: ChatViewTableViewVoiceMessageCellDelegate,
        showConversationInformation: ShowConversationInformation? = nil
    ) {
        self.conversation = conversation
        self.chatViewActionsHelper = chatViewControllerActionsHelper
        self.chatViewController = chatViewController
        self.chatBarCoordinatorDelegate = chatBarCoordinatorDelegate
        self.chatViewTableViewVoiceMessageCellDelegate = chatViewTableViewVoiceMessageCellDelegate
        self.businessInjector = BusinessInjector()
                    
        // If we received an notification, we check if it has text or an image in it,
        // else we check for draft texts.
        if let notificationText = showConversationInformation?.precomposedText {
            self.precomposedText = notificationText
        }
        else if let image = showConversationInformation?.image {
            previewPrecomposedImage(image)
        }
        else {
            if let draft = MessageDraftStore.shared.loadDraft(for: self.conversation) {
                switch draft {
                case let .text(string):
                    self.precomposedText = string
                    
                case let .audio(url):
                    startRecording(with: url)
                    
                case let .json(subtype):
                    switch subtype {
                    case let .quote(text, objectIDString):
                        guard let quotedMessage = businessInjector.entityManager.entityFetcher
                            .existingObject(withIDString: objectIDString) as? QuoteMessage else {
                            MessageDraftStore.shared.deleteDraft(for: conversation)
                            return
                        }
                        self.precomposedText = text
                        showQuoteView(for: quotedMessage)
                        
                    case let .edit(text, objectIDString):
                        guard let editMessage = businessInjector.entityManager.entityFetcher
                            .existingObject(withIDString: objectIDString) as? EditedMessage else {
                            MessageDraftStore.shared.deleteDraft(for: conversation)
                            return
                        }
                        self.precomposedText = text
                        showEditedMessageView(for: editMessage)
                    }
                }
            }
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let sentMessageSoundID {
            AudioServicesDisposeSystemSoundID(sentMessageSoundID)
        }
    }
    
    // MARK: - Updates
    
    func updateSettings() {
        updateMessagePermission()
        chatBar.updateSendButton()
    }
    
    func saveDraft(andDeleteText: Bool = false) {
        if isRecording {
            guard let mode = chatBarCoordinatorDelegate?.userInterfaceMode else {
                return
            }
            
            Task {
                // Avoid file operations if the chat is peeked
                let currentState = await chatBar.getCurrentSessionState(shouldMove: mode != .preview)
                await MainActor.run {
                    switch currentState {
                    case .background:
                        break
                    case let .closed(audioFile):
                        MessageDraftStore.shared.saveDraft(.audio(audioFile), for: conversation)
                    case nil:
                        MessageDraftStore.shared.deleteDraft(for: conversation)
                    }
                }
            }
        }
        else if let quoteMessage {
            guard let currentText = chatBar.getCurrentText() else {
                MessageDraftStore.shared.deleteDraft(for: conversation)
                return
            }
            
            if andDeleteText {
                chatBar.removeCurrentText()
            }
            
            let currentOrEmptyText = ThreemaUtility.trimCharacters(in: currentText)
            
            guard !currentOrEmptyText.isEmpty else {
                MessageDraftStore.shared.deleteDraft(for: conversation)
                return
            }
            
            let draftSubType = Draft.SubType.quote(
                currentOrEmptyText,
                quoteMessage.objectID.uriRepresentation().absoluteString
            )
            MessageDraftStore.shared.saveDraft(.json(draftSubType), for: conversation)
        }
        else if let messageToEdit {
            guard let currentText = chatBar.getCurrentText() else {
                MessageDraftStore.shared.deleteDraft(for: conversation)
                return
            }
            
            if andDeleteText {
                chatBar.removeCurrentText()
            }
            
            let currentOrEmptyText = ThreemaUtility.trimCharacters(in: currentText)
            
            guard !currentOrEmptyText.isEmpty else {
                MessageDraftStore.shared.deleteDraft(for: conversation)
                return
            }
            
            let draftSubType = Draft.SubType.edit(
                currentOrEmptyText,
                messageToEdit.objectID.uriRepresentation().absoluteString
            )
            MessageDraftStore.shared.saveDraft(.json(draftSubType), for: conversation)
        }
        else {
            guard let currentText = chatBar.getCurrentText() else {
                MessageDraftStore.shared.deleteDraft(for: conversation)
                return
            }
            
            if andDeleteText {
                chatBar.removeCurrentText()
            }
            
            let currentOrEmptyText = ThreemaUtility.trimCharacters(in: currentText)
            
            guard !currentOrEmptyText.isEmpty else {
                MessageDraftStore.shared.deleteDraft(for: conversation)
                return
            }
            
            MessageDraftStore.shared.saveDraft(.text(currentOrEmptyText), for: conversation)
        }
    }

    /// Shows the edited message view for message on top of the chat bar. Removes currently existing edited and
    /// quote message views
    /// - Parameter message: Message to edit
    func showEditedMessageView(for message: EditedMessage) {
        // Remove quote view if it was shown
        if quoteMessage != nil {
            removeQuoteView()
        }
        
        // Reset edit view if it was shown
        if messageToEdit != nil {
            removeEditedMessageView()
        }

        chatBar
            .updateSendButtonAccessibilityLabel(
                to: "compose_bar_send_edited_message_button_accessibility_label"
                    .localized
            )
        messageToEdit = message
        let editedView = ChatBarEditedMessageView(editedMessage: message, delegate: self)
        chatBarContainerView.add(editedView)
        chatBarContainerView.becomeFirstResponder()
        chatBar.disablePlusButton()
    }

    /// Removes the currently displayed edit message view
    func removeEditedMessageView() {
        chatBar.updateSendButtonAccessibilityLabel(to: #localize("compose_bar_send_message_button_accessibility_label"))
        messageToEdit = nil
        chatBarContainerView.removeEditedMessageView()
        chatBar.removeCurrentText()
        chatBar.enablePlusButton()
    }

    /// Shows the quote view for message on top of the chat bar. Removes currently existing quote or edit views
    /// - Parameter message: Message to be quoted
    func showQuoteView(for message: QuoteMessage) {
        // Remove edit view if it was shown
        if messageToEdit != nil {
            removeEditedMessageView()
        }
        
        // Reset quote view if it was shown
        if quoteMessage != nil {
            removeQuoteView()
        }
        
        quoteMessage = message
        let quoteView = ChatBarQuoteView(quotedMessage: message, delegate: self)
        chatBarContainerView.add(quoteView)
        chatBarContainerView.becomeFirstResponder()
    }
    
    /// Removes the currently displayed quote view
    func removeQuoteView() {
        quoteMessage = nil
        chatBarContainerView.removeQuoteView()
        chatBarCoordinatorDelegate?.didDismissQuoteView()
    }
    
    /// Updates colors for all subviews
    func updateColors() {
        mentionsTableViewController?.updateColors()
    }
    
    /// Shows chat bar
    func showChatBar() {
        chatBarContainerView.isHidden = false
    }
    
    /// Hides chat bar
    func hideChatBar() {
        chatBarContainerView.isHidden = true
    }
}

// MARK: - Mentions Handling

extension ChatBarCoordinator {
    private var shouldShowMentionsTableView: Bool {
        conversation.isGroup
    }
    
    private func addMentionsView() {
        var mentionableMembers: [MentionableIdentity] = [MentionableIdentity()]
        for member in conversation.unwrappedMembers {
            mentionableMembers.append(MentionableIdentity(
                identity: member.identity,
                entityFetcher: businessInjector.entityManager.entityFetcher
            ))
        }
        
        self.mentionsTableViewController = MentionsTableViewController(
            mentionsDelegate: self,
            mentions: mentionableMembers
        )
        
        guard let mentionsTableViewController else {
            DDLogError("mentionsTableViewController was improperly initialized")
            return
        }
        
        chatBarContainerView.add(mentionsTableViewController)
        mentionsVisible = true
    }
    
    private func showMentionsView() {
        #if DEBUG
            dispatchPrecondition(condition: .onQueue(.main))
        #endif
        
        if !mentionsVisible {
            addMentionsView()
            mentionsVisible = true
        }
        
        chatBarContainerView.updateMentionsTableViewHeight()
    }
    
    private func hideMentionsView() {
        #if DEBUG
            dispatchPrecondition(condition: .onQueue(.main))
        #endif
        
        if mentionsVisible {
            chatBarContainerView.removeMentionsTableView()
            mentionsVisible = false
        }
    }
    
    /// Sends endEditing to the textView
    public func endEditing() {
        chatBar.endEditing()
    }
    
    /// Resigns the first responder in all subviews
    /// - Returns:Always true
    @discardableResult func resignFirstResponder() -> Bool {
        chatBarContainerView.resignFirstResponder()
    }
}

// MARK: - MentionsTableViewDelegate

extension ChatBarCoordinator: MentionsTableViewDelegate {
    func contactSelected(contact: MentionableIdentity) {
        chatBar.mentionSelected(identity: contact.mentionIdentity)
        hideMentionsView()
    }
    
    func hasMatches(for searchString: String) -> Bool {
        if mentionsTableViewController == nil {
            addMentionsView()
        }
        
        guard let mentionsTableViewController else {
            DDLogError("mentionsTableViewController was improperly initialized")
            return false
        }
        
        return shouldShowMentionsTableView && mentionsTableViewController.match(searchString)
    }
    
    func shouldHideMentionsTableView(_ shouldHide: Bool) {
        if shouldHide {
            hideMentionsView()
        }
        else {
            showMentionsView()
        }
    }
}

// MARK: - ChatBarViewDelegate

extension ChatBarCoordinator: ChatBarViewDelegate {
    
    func checkIfPastedStringIsMedia() -> Bool {
        sendOrPreviewPastedItem()
    }
    
    func setIsResettingKeyboard(_ setReset: Bool) {
        chatViewController?.isResettingKeyboard = setReset
    }

    func showCamera() {
        guard let action = SendMediaAction(for: chatViewActionsHelper) else {
            let message = "Could not create SendMediaAction in \(#function)"
            DDLogError("\(message)")
            assertionFailure(message)
            return
        }
        
        chatViewActionsHelper.currentLegacyAction = action
        action.mediaPickerType = MediaPickerTakePhoto
        
        resignFirstResponder()
        
        action.execute()
    }
    
    func showImagePicker() {
        guard let action = SendMediaAction(for: chatViewActionsHelper) else {
            let message = "Could not create SendMediaAction in \(#function)"
            DDLogError("\(message)")
            assertionFailure(message)
            return
        }
        
        chatViewActionsHelper.currentLegacyAction = action
        
        action.mediaPickerType = MediaPickerChooseExisting
        
        resignFirstResponder()
        
        action.execute()
    }
    
    func showAssetsSelector() {
        guard let chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        
        let assetActionHelper = PPAssetsActionHelper()
        assetActionHelper.delegate = self
        
        let assetActionController = assetActionHelper.buildAction()
        
        chatViewController.present(assetActionController, animated: true, completion: nil)
    }
    
    @discardableResult
    func sendOrPreviewPastedItem() -> Bool {
        guard canSendText() else {
            return false
        }
        
        let stickerTypes = ["com.apple.png-sticker", "com.apple.sticker"]
        let containsMemoji = UIPasteboard.general.contains(pasteboardTypes: stickerTypes) && UIPasteboard.general
            .numberOfItems == 1
        
        if containsMemoji {
            guard let image = UIPasteboard.general.image?.pngData() else {
                showPasteError()
                return false
            }
            
            guard let uti = ImageURLSenderItemCreator.getUTI(for: image) as? String else {
                showPasteError()
                return false
            }
            
            let imageSender = ImageURLSenderItemCreator()
            if let senderItem = imageSender.senderItem(from: image, uti: uti) {
                Task {
                    do {
                        try await businessInjector.messageSender.sendBlobMessage(
                            for: senderItem,
                            in: conversation.objectID
                        )
                    }
                    catch {
                        DDLogError("Could not create message and sync blobs due to: \(error)")
                    }
                }
            }
            Task { @MainActor in
                chatBar.resetKeyboard()
            }
            return true
        }
        else {
            let itemLoader = ItemLoader(forceLoadFileURLItem: true)
            for itemProvider in UIPasteboard.general.itemProviders {
                let baseType = ItemLoader.getBaseUTIType(itemProvider)
                let secondaryType = ItemLoader.getSecondUTIType(itemProvider, baseType: baseType)
                itemLoader.addItem(itemProvider: itemProvider, type: baseType, secondType: secondaryType)
            }
            
            if let loadedItems = itemLoader.syncLoadContentItems(), !loadedItems.isEmpty {
                showPastedItemsPreview(loadedItems)
                return true
            }
            else {
                return false
            }
        }
    }
    
    @available(iOS 18.0, *)
    func processAndSendGlyph(_ glyph: NSAdaptiveImageGlyph) {
        
        let imageSender = ImageURLSenderItemCreator()
        if let senderItem = imageSender.senderItem(from: glyph.imageContent, uti: UTType.png.identifier) {
            Task {
                do {
                    try await businessInjector.messageSender.sendBlobMessage(
                        for: senderItem,
                        in: conversation.objectID
                    )
                }
                catch {
                    DDLogError("Could not create message and sync blobs due to: \(error)")
                }
            }
        }
        Task { @MainActor in
            chatBar.resetKeyboard()
        }
    }
    
    private func showPastedItemsPreview(_ items: [Any]) {
        guard let sendMediaAction = SendMediaAction(for: chatViewActionsHelper) else {
            assertionFailure()
            return
        }
        sendMediaAction.showPreview(forAssets: items)
    }
    
    private func previewPrecomposedImage(_ image: UIImage) {
        let item = ImagePreviewItem()
        let filename = "composed-image-\(UUID().uuidString).png"
        let url = FileUtility.shared.appTemporaryDirectory.appendingPathComponent(filename)
        guard let imageData = MediaConverter.pngRepresentation(for: image) else {
            showPasteError()
            return
        }
        do {
            try imageData.write(to: url)
        }
        catch {
            showPasteError()
        }
        
        item.itemURL = url
        item.filename = filename
        
        guard let sendMediaAction = SendMediaAction(for: chatViewActionsHelper) else {
            showPasteError()
            return
        }
        
        sendMediaAction.showPreview(forAssets: [item])
    }
    
    func showPasteError() {
        let title = #localize("pasteErrorMessageTitle")
        let message = #localize("pasteErrorMessageMessage")
        DispatchQueue.main.async {
            UIAlertTemplate.showAlert(
                owner: AppDelegate.shared().currentTopViewController(),
                title: title,
                message: message,
                actionOk: nil
            )
        }
    }
    
    func canSendText() -> Bool {
        canSendText().isAllowed
    }
    
    func canSendText() -> (isAllowed: Bool, reason: String?) {
        if let group = businessInjector.groupManager.getGroup(conversation: conversation) {
            return messagePermission.canSend(groudID: group.groupID, groupCreatorIdentity: group.groupCreatorIdentity)
        }
        else if let distributionList = conversation.distributionList {
            // TODO: (IOS-4366) Check send possible for each recipient
            return (true, nil)
        }
        else {
            guard let contact = conversation.contact else {
                return (false, nil)
            }
            return messagePermission.canSend(to: contact.identity)
        }
    }
    
    func sendText(rawText: String) {
        guard canSendText() else {
            return
        }
                
        var sendableRawText = rawText
        // Sending
        // Edit Message
        if let messageToEdit {
            let group = businessInjector.groupManager.getGroup(conversation: messageToEdit.conversation)
            guard !messageToEdit.wasSentMoreThanSixHoursAgo || (group?.isNoteGroup ?? false) else {
                showEditMessageSentTooLongAgoAlert()
                return
            }
           
            var unsupportedContacts = FeatureMask.check(
                message: messageToEdit,
                for: .editMessageSupport
            ).unsupported
            
            // We filter out certain contacts in groups that will not receive the message anyway
            if let group {
                var filteredUnsupportedContact = [Contact]()
                
                for unsupportedContact in unsupportedContacts {
                    // If the contact has a gateway ID and is the creator of the group the message is sent in…
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
            
            do {
                try businessInjector.messageSender.sendEditMessage(
                    with: messageToEdit.objectID,
                    rawText: rawText,
                    receiversExcluded: unsupportedContacts
                )
            }
            catch MessageSenderError.editedTextToLong {
                showEditMessageSentTooLongAlert()
                return
            }
            catch {
                DDLogError("Send edit message for edited message failed \(messageToEdit.id.hexString)")
                return
            }
            
            if !unsupportedContacts.isEmpty {
                showEditMessageNotSentAlert(for: unsupportedContacts)
            }
            removeEditedMessageView()
        }
        // Quote Message
        else if let quoteMessage {
            assert(conversation.distributionList == nil, "Quoting in distribution lists is not allowed!")
            sendableRawText = QuoteUtil.generateText(rawText, with: quoteMessage.id)
            businessInjector.messageSender.sendTextMessage(containing: sendableRawText, in: conversation)
            removeQuoteView()
        }
        // New Message
        else {
            businessInjector.messageSender.sendTextMessage(containing: sendableRawText, in: conversation)
        }
        
        chatBar.removeCurrentText()
        
        MessageDraftStore.shared.deleteDraft(for: conversation)
        
        ConversationActions(businessInjector: businessInjector).unarchive(conversation)
        
        if UserSettings.shared().inAppSounds, let sentMessageSoundID {
            AudioServicesPlaySystemSound(sentMessageSoundID)
        }
    }
    
    private func showEditMessageSentTooLongAgoAlert() {
        guard let chatViewController else {
            return
        }
        
        UIAlertTemplate.showAlert(
            owner: chatViewController,
            title: #localize("edit_message"),
            message: #localize("edit_message_can_not_edit")
        )
    }
    
    private func showEditMessageNotSentAlert(for contacts: [Contact]) {
        guard let chatViewController else {
            return
        }
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
                summary = "\(totalSummary)\n\(#localize("edit_message_requirement"))"
            }
        }
        else {
            if let shortsSummary = listFormatter.string(from: displayNames) {
                summary = "\(shortsSummary)\n\(#localize("edit_message_requirement"))"
            }
        }
        
        let message = String.localizedStringWithFormat(#localize("edit_message_not_sent_to"), summary)
        UIAlertTemplate.showAlert(
            owner: chatViewController,
            title: #localize("edit_message"),
            message: message
        )
    }
    
    private func showEditMessageSentTooLongAlert() {
        guard let chatViewController else {
            return
        }
        
        UIAlertTemplate.showAlert(
            owner: chatViewController,
            title: #localize("edit_message"),
            message: #localize("edit_message_text_to_long")
        )
    }
        
    func startRecording(with audioFileURL: URL? = nil) {
        chatViewTableViewVoiceMessageCellDelegate?.pausePlaying()
        
        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: nil)
        
        Benchmark.run {
            self.chatBar.presentVoiceMessageRecorderView(with: self, with: audioFileURL)
        }
        
        isRecording = true
    }
    
    func sendTypingIndicator(startTyping: Bool) {
        // Only send typing indicator in groups
        // Only send typing indicator if the conversation has a contact (equivalent to being a group but we want the
        // identity to not be optional)
        // Do not send false twice in a row
        if !conversation.isGroup, let identity = conversation.contact?.threemaIdentity,
           (!startTyping && lastTypingIndicatorState) || startTyping {
            DDLogVerbose("Send typing indicator \(startTyping)")
            businessInjector.messageSender.sendTypingIndicator(typing: startTyping, toIdentity: identity)
            lastTypingIndicatorState = startTyping
        }
    }
    
    func stopTypingTimers() {
        chatBar.stopTypingTimer()
    }
    
    func updateLayoutForTextChange() {
        UIView.animate(
            withDuration: ChatViewConfiguration.ChatBar.ContentInsetAnimation.totalDuration,
            delay: ChatViewConfiguration.ChatBar.ContentInsetAnimation.delay,
            options: .curveEaseInOut,
            animations: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                guard let chatViewController = strongSelf.chatViewController else {
                    DDLogError("chatViewController should not be nil when calling \(#function)")
                    return
                }
                chatViewController.updateContentInsets()
                strongSelf.chatBarContainerView.layoutIfNeeded()
            },
            completion: nil
        )
    }
    
    func showContact(identity: String) {
        if let contact = BusinessInjector().entityManager.entityFetcher.contact(for: identity) {
            let detailsViewController = SingleDetailsViewController(for: Contact(contactEntity: contact))
            let navigationController = ThemedNavigationController(rootViewController: detailsViewController)
            navigationController.modalPresentationStyle = .formSheet
            
            chatViewController?.present(navigationController, animated: true)
        }
        else if identity == BusinessInjector().myIdentityStore.identity {
            // TODO: IOS-2927 Refactor `MeContactDetailsViewController` to allow removing `MainStoryboard`
            let storyboard = UIStoryboard(name: "MainStoryboard", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "meContactDetailsViewController")
            
            let navigationController = ModalNavigationController(rootViewController: vc)
            navigationController.modalPresentationStyle = .formSheet
            navigationController.showDoneButton = true
            
            chatViewController?.present(navigationController, animated: true)
        }
        else {
            DDLogError("Can't find contact for tapped mention")
        }
    }

    func isEditedMessageSet() -> Bool {
        messageToEdit != nil
    }
}

// MARK: - PPAssetsActionHelperDelegate

extension ChatBarCoordinator: PPAssetsActionHelperDelegate {
    
    var conversationIsDistributionList: Bool {
        conversation.distributionList != nil
    }
    
    func assetsActionHelperDidCancel(_ picker: PPAssetsActionHelper) {
        // We do not do anything on cancel
    }
    
    func assetsActionHelper(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) {
        // We do not do anything in this case
    }
    
    func assetActionHelperDidSelectOwnOption(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) {
        guard let sendMediaAction = SendMediaAction(for: chatViewActionsHelper) else {
            let message = "Could not create SendMediaAction in \(#function)"
            DDLogError("\(message)")
            assertionFailure(message)
            return
        }
        guard let chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        sendMediaAction.sendAssets(assets, asFile: false, withCaptions: nil)
    }
    
    func assetsActionHelperDidSelectOwnSnapButton(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) {
        guard let action = SendMediaAction(for: chatViewActionsHelper) else {
            let message = "Could not create SendMediaAction in \(#function)"
            DDLogError("\(message)")
            assertionFailure(message)
            return
        }
        guard let chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        
        chatViewController.dismiss(animated: true, completion: nil)
        
        if !assets.isEmpty {
            action.showPreview(forAssets: assets, showKeyboard: true)
        }
        else {
            action.mediaPickerType = MediaPickerChooseExisting
            action.execute()
        }
    }
    
    func assetsActionHelperDidSelectLiveCameraCell(_ picker: PPAssetsActionHelper) {
        guard let chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        
        chatViewController.dismiss(animated: true, completion: nil)
        
        guard let action = SendMediaAction(for: chatViewActionsHelper) else {
            let message = "Could not create SendMediaAction in \(#function)"
            DDLogError("\(message)")
            assertionFailure(message)
            return
        }
        
        chatViewActionsHelper.currentLegacyAction = action
        
        action.mediaPickerType = MediaPickerTakePhoto
        action.execute()
    }
    
    func assetsActionHelperDidSelectLocation(_ picker: PPAssetsActionHelper) {
        guard let sendLocationAction = SendLocationAction(for: chatViewActionsHelper) else {
            let message = "Could not create SendLocationAction"
            DDLogError("\(message)")
            assertionFailure(message)
            return
        }
        guard let chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        sendLocationAction.execute()
    }
    
    func assetsActionHelperDidSelectRecordAudio(_ picker: PPAssetsActionHelper) {
        guard let chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        startRecording()
    }
    
    func assetsActionHelperDidSelectCreateBallot(_ picker: PPAssetsActionHelper) {
        guard let chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        BallotDispatcher.showBallotCreateViewController(
            forConversation: conversation,
            on: chatViewController.navigationController
        )
    }
    
    func assetsActionHelperDidSelectScanDocument(_ picker: PPAssetsActionHelper) {
        guard let chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        let vc = VNDocumentCameraViewController()
        vc.delegate = chatViewController
        chatViewController.present(vc, animated: true)
    }
    
    func assetsActionHelperDidSelectShareFile(_ picker: PPAssetsActionHelper) {
        guard let documentPicker = DocumentPicker(for: chatViewController, conversation: conversation) else {
            let message = "Could not create DocumentPicker"
            DDLogError("\(message)")
            assertionFailure(message)
            return
        }
        guard let chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        documentPicker.show()
    }
}

// MARK: - ChatBarEditedMessageViewDelegate

extension ChatBarCoordinator: ChatBarEditedMessageViewDelegate {
    func editedMessageDismissed() {
        removeEditedMessageView()
    }

    var editedMessageTextBeginningInset: CGFloat {
        chatBar.textBeginningInset
    }
}

// MARK: - ChatBarQuoteViewDelegate

extension ChatBarCoordinator: ChatBarQuoteViewDelegate {
    func quoteDismissed() {
        removeQuoteView()
    }
    
    var textBeginningInset: CGFloat {
        chatBar.textBeginningInset
    }
}

// MARK: - MessagePermission handling

extension ChatBarCoordinator {
    private func updateMessagePermission() {
        if !canSendText() {
            let catchTapOnDisabledView = UIView(frame: .zero)
            catchTapOnDisabledView.backgroundColor = .clear
            catchTapOnDisabledView.translatesAutoresizingMaskIntoConstraints = false
            
            let tapGr = UITapGestureRecognizer(target: self, action: #selector(showMessagePermissionNotGranted))
            tapGr.cancelsTouchesInView = true
            catchTapOnDisabledView.addGestureRecognizer(tapGr)
            
            chatBarContainerView.disableInteraction(with: catchTapOnDisabledView)
        }
        else {
            chatBarContainerView.enableInteraction()
        }
    }
    
    @objc func showMessagePermissionNotGranted() {
        guard let chatViewController else {
            DDLogError("Cannot show alert for unable to send text because chatViewController is nil.")
            return
        }

        let canSendText: (isAllowed: Bool, reason: String?) = canSendText()
        if !canSendText.isAllowed, let reason = canSendText.reason {
            UIAlertTemplate.showAlert(owner: chatViewController, title: reason, message: nil)
        }
        else {
            updateMessagePermission()
        }
    }
}

// MARK: - VoiceMessageRecorderViewDelegate

extension ChatBarCoordinator: VoiceMessageRecorderViewDelegate {
    func willDismissRecorder() {
        chatBar.dismissVoiceMessageRecorderView()
        isRecording = false
        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: nil)
    }
}
