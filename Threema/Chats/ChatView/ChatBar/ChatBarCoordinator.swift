//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import ThreemaFramework
import UIKit

protocol ChatBarCoordinatorDelegate: AnyObject {
    func didDismissQuoteView()
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
    
    // MARK: - Private properties
    
    private var conversation: Conversation
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
        conversation: Conversation,
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
            self.precomposedText = MessageDraftStore.loadDraft(for: self.conversation)
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Updates
    
    func updateSettings() {
        updateMessagePermission()
    }
    
    func saveDraft(andDeleteText: Bool = false) {
        guard let currentText = chatBar.getCurrentText(andRemove: andDeleteText) else {
            MessageDraftStore.deleteDraft(for: conversation)
            return
        }
        
        let currentOrEmptyText = ThreemaUtility.trimCharacters(in: currentText)
        
        MessageDraftStore.saveDraft(currentOrEmptyText, for: conversation)
    }
    
    /// Shows the quote view for message on top of the chat bar. Removes currently existing quote views
    /// - Parameter message: Message to be quoted
    func showQuoteView(for message: QuoteMessage) {
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
        chatBar.updateColors()
        chatBarContainerView.updateColors()
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
        conversation.isGroup()
    }
    
    private func addMentionsView() {
        var mentionableMembers: [MentionableIdentity] = [MentionableIdentity()]
        for member in conversation.members {
            mentionableMembers.append(MentionableIdentity(
                identity: member.identity,
                entityFetcher: businessInjector.entityManager.entityFetcher
            ))
        }
        
        self.mentionsTableViewController = MentionsTableViewController(
            mentionsDelegate: self,
            mentions: mentionableMembers
        )
        
        guard let mentionsTableViewController = mentionsTableViewController else {
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
            mentionsTableViewController = nil
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
        
        guard let mentionsTableViewController = mentionsTableViewController else {
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
            DDLogError(message)
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
            DDLogError(message)
            assertionFailure(message)
            return
        }
        
        chatViewActionsHelper.currentLegacyAction = action
        
        action.mediaPickerType = MediaPickerChooseExisting
        
        resignFirstResponder()
        
        action.execute()
    }
    
    func showAssetsSelector() {
        guard let chatViewController = chatViewController else {
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
        
        let stickerTypes = ["com.apple.png-sticker"]
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
                        try await BlobManager.shared.createMessageAndSyncBlobs(
                            for: senderItem,
                            in: conversation.objectID
                        )
                    }
                    catch {
                        DDLogError("Could not create message and sync blobs due to: \(error)")
                    }
                }
            }
            return true
            chatBar.resetKeyboard(andType: true)
        }
        else {
            let itemLoader = ItemLoader(forceLoadFileURLItem: true)
            for itemProvider in UIPasteboard.general.itemProviders {
                let baseType = ItemLoader.getBaseUTIType(itemProvider)
                let secondaryType = ItemLoader.getSecondUTIType(itemProvider)
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
        
        guard let url = FileUtility.appTemporaryDirectory?.appendingPathComponent(filename) else {
            showPasteError()
            return
        }
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
        let title = BundleUtil.localizedString(forKey: "pasteErrorMessageTitle")
        let message = BundleUtil.localizedString(forKey: "pasteErrorMessageMessage")
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
        
        if let quoteMessage = quoteMessage {
            sendableRawText = QuoteUtil.generateText(rawText, with: quoteMessage.id)
        }
                
        MessageSender.sanitizeAndSendText(sendableRawText, in: conversation)
        
        MessageDraftStore.deleteDraft(for: conversation)
        
        ConversationActions(businessInjector: businessInjector).unarchive(conversation)
        
        if quoteMessage != nil {
            removeQuoteView()
        }
        
        if UserSettings.shared().inAppSounds, let sentMessageSoundID {
            AudioServicesPlaySystemSound(sentMessageSoundID)
        }
    }
        
    func startRecording() {
        chatViewTableViewVoiceMessageCellDelegate?.pausePlaying()
        
        PlayRecordAudioViewController.requestMicrophoneAccess {
            UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: nil)
            guard let audioRecorder = PlayRecordAudioViewController(in: self.chatViewController) else {
                guard let chatViewController = self.chatViewController else {
                    DDLogError("chatViewController should not be nil when calling \(#function)")
                    return
                }
                UIAlertTemplate.showAlert(
                    owner: chatViewController,
                    title: "play_record_audio_view_controller_general_error_message",
                    message: "play_record_audio_view_controller_general_error_message"
                )
                return
            }
            audioRecorder.delegate = self
            audioRecorder.startRecording(for: self.conversation)
            
            self.chatBar.isUserInteractionEnabled = false
        }
    }
    
    func sendTypingIndicator(startTyping: Bool) {
        // Only send typing indicator in groups
        // Only send typing indicator if the conversation has a contact (equivalent to being a group but we want the identity to not be optional)
        // Do not send false twice in a row
        if !conversation.isGroup(), let identity = conversation.contact?.identity,
           (!startTyping && lastTypingIndicatorState) || startTyping {
            DDLogVerbose("Send typing indicator \(startTyping)")
            MessageSender.sendTypingIndicatorMessage(startTyping, toIdentity: identity)
            lastTypingIndicatorState = startTyping
        }
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
}

// MARK: - PPAssetsActionHelperDelegate

extension ChatBarCoordinator: PPAssetsActionHelperDelegate {
    func assetsActionHelperDidCancel(_ picker: PPAssetsActionHelper) {
        // We do not do anything on cancel
    }
    
    func assetsActionHelper(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) {
        // We do not do anything in this case
    }
    
    func assetActionHelperDidSelectOwnOption(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) {
        guard let sendMediaAction = SendMediaAction(for: chatViewActionsHelper) else {
            let message = "Could not create SendMediaAction in \(#function)"
            DDLogError(message)
            assertionFailure(message)
            return
        }
        guard let chatViewController = chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        sendMediaAction.sendAssets(assets, asFile: false, withCaptions: nil)
    }
    
    func assetsActionHelperDidSelectOwnSnapButton(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) {
        guard let action = SendMediaAction(for: chatViewActionsHelper) else {
            let message = "Could not create SendMediaAction in \(#function)"
            DDLogError(message)
            assertionFailure(message)
            return
        }
        guard let chatViewController = chatViewController else {
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
        guard let chatViewController = chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        
        chatViewController.dismiss(animated: true, completion: nil)
        
        guard let action = SendMediaAction(for: chatViewActionsHelper) else {
            let message = "Could not create SendMediaAction in \(#function)"
            DDLogError(message)
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
            DDLogError(message)
            assertionFailure(message)
            return
        }
        guard let chatViewController = chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        sendLocationAction.execute()
    }
    
    func assetsActionHelperDidSelectRecordAudio(_ picker: PPAssetsActionHelper) {
        guard let chatViewController = chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        startRecording()
    }
    
    func assetsActionHelperDidSelectCreateBallot(_ picker: PPAssetsActionHelper) {
        guard let chatViewController = chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        BallotDispatcher.showBallotCreateViewController(for: conversation, on: chatViewController.navigationController)
    }
    
    func assetsActionHelperDidSelectShareFile(_ picker: PPAssetsActionHelper) {
        guard let documentPicker = DocumentPicker(for: chatViewController, conversation: conversation) else {
            let message = "Could not create DocumentPicker"
            DDLogError(message)
            assertionFailure(message)
            return
        }
        guard let chatViewController = chatViewController else {
            DDLogError("chatViewController should not be nil when calling \(#function)")
            return
        }
        chatViewController.dismiss(animated: true, completion: nil)
        documentPicker.show()
    }
}

// MARK: - PlayRecordAudioDelegate

extension ChatBarCoordinator: PlayRecordAudioDelegate {
    func audioPlayerDidHide() {
        chatBar.isUserInteractionEnabled = true
        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: nil)
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
        guard let chatViewController = chatViewController else {
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
