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
import SwiftUI
import ThreemaFramework
import ThreemaMacros
import UIKit

protocol ChatBarViewDelegate: AnyObject {
    // Sending or previewing items
    func canSendText() -> Bool
    func sendText(rawText: String)
    func sendTypingIndicator(startTyping: Bool)
    @discardableResult
    func sendOrPreviewPastedItem() -> Bool
    @available(iOS 18.0, *)
    func processAndSendGlyph(_ glyph: NSAdaptiveImageGlyph)
    func showAssetsSelector()
    func showCamera()
    func showImagePicker()
    func checkIfPastedStringIsMedia() -> Bool
    func showContact(identity: String)
    func isEditedMessageSet() -> Bool

    // Voice Messages
    func startRecording(with audioFileURL: URL?)
    
    // Animations
    func updateLayoutForTextChange()

    func setIsResettingKeyboard(_ setReset: Bool)
}

final class ChatBarView: UIView {
    
    // MARK: -  Typealias
    
    private typealias Config = ChatViewConfiguration.ChatBar
    private typealias UpdatableConstraint = (constraint: NSLayoutConstraint, offset: CGFloat)
    
    // MARK: - Properties
    
    var textBeginningInset: CGFloat {
        chatTextView.textBeginningInset
    }
    
    var isTextViewFirstResponder: Bool {
        chatTextView.isFirstResponder
    }
    
    weak var chatBarViewDelegate: ChatBarViewDelegate?

    // MARK: - Private properties
    
    private let markupParser = MarkupParser()
    private let conversation: ConversationEntity
    private let precomposedText: String?
    
    private var voiceMessageController: VoiceMessageRecorderViewController?
    
    private var isTyping = false
    
    /// Timer which sends a typing message to avoid the other device cancelling the typing status
    private var continueTypingTimer: Timer?
    /// Timer which sends stop typing message if the user has not updated the text field within the past n seconds
    private var typingTimer: Timer?
    
    private var sendButtonConstraint: NSLayoutConstraint?
    private var cameraMicButtonConstraint: NSLayoutConstraint?
    
    private var currentSingleLineHeight: CGFloat = Config.defaultSingleLineHeight
    private var updatableConstraints = [UpdatableConstraint]()
    
    private lazy var feedbackGenerator = UINotificationFeedbackGenerator()

    // MARK: - Views
    
    private lazy var chatTextView: ChatTextView = {
        let chatTextView = ChatTextView(
            precomposedText: precomposedText,
            conversationIdentifier: conversation.objectID.uriRepresentation().absoluteString
        )
        
        chatTextView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        chatTextView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        return chatTextView
    }()
    
    // MARK: Buttons
    
    private lazy var plusButton: ChatBarButton = {
        let imageButton = ChatBarButton(
            sfSymbolName: "plus.circle.fill",
            accessibilityLabel: #localize("compose_bar_attachment_button_accessibility_label"),
            defaultColor: { Colors.backgroundChatBarButton },
            customScalableSize: Config.plusButtonSize
        ) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            if strongSelf.chatBarViewDelegate?.canSendText() ?? false {
                strongSelf.chatBarViewDelegate?.showAssetsSelector()
            }
        }
        
        imageButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageButton.accessibilityIdentifier = "ChatBarViewImageButton"
        
        return imageButton
    }()
    
    private lazy var rightButtonsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            cameraButton,
            imagePickerButton,
            recordButton,
        ])
        
        cameraButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imagePickerButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        recordButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillProportionally
        stack.spacing = Config.cameraMicSpacing
        
        stack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        return stack
    }()
    
    private lazy var sendButton: ChatBarButton = {
        let imageButton = ChatBarButton(
            sfSymbolName: "arrow.up.circle.fill",
            accessibilityLabel: #localize("compose_bar_send_message_button_accessibility_label"),
            defaultColor: { .tintColor },
            customScalableSize: Config.sendButtonSize
        ) { [weak self] _ in
            
            guard let strongSelf = self else {
                return
            }
            
            if strongSelf.chatBarViewDelegate?.canSendText() ?? false {
                strongSelf.sendText()
            }
        }
        
        imageButton.isHidden = true
        imageButton.alpha = 0.0
        
        imageButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        return imageButton
    }()
    
    private lazy var recordButton = {
        let button = ChatBarButton(
            sfSymbolName: "mic.fill",
            accessibilityLabel: #localize("compose_bar_record_button_accessibility_label"),
            defaultColor: { Colors.backgroundChatBarButton }
        ) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            if strongSelf.chatBarViewDelegate?.canSendText() ?? false {
                strongSelf.chatBarViewDelegate?.startRecording(with: nil)
            }
        }
        
        // This is deprecated but since we're not using UIButtonConfiguration anyways this doesn't matter
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: Config.textInputButtonSpacing)
        
        return button
    }()
    
    private lazy var cameraButton = ChatBarButton(
        sfSymbolName: "camera.fill",
        accessibilityLabel: #localize("compose_bar_camera_button_accessibility_label"),
        defaultColor: { Colors.backgroundChatBarButton }
    ) { [weak self] _ in
        guard let strongSelf = self else {
            return
        }
        
        if strongSelf.chatBarViewDelegate?.canSendText() ?? false {
            let avCaptureDeviceStatus = AVCaptureDevice.authorizationStatus(for: .video)
            guard UIImagePickerController.isSourceTypeAvailable(.camera),
                  avCaptureDeviceStatus != .denied else {
                // switch camera to image picker icon
                strongSelf.configureLayout()
                
                return
            }
            
            if avCaptureDeviceStatus == .authorized {
                strongSelf.chatBarViewDelegate?.showCamera()
            }
            else {
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                    DispatchQueue.main.async {
                        if granted {
                            strongSelf.chatBarViewDelegate?.showCamera()
                        }
                        else {
                            // switch camera to image picker icon
                            strongSelf.configureLayout()
                        }
                    }
                })
            }
        }
    }
    
    private lazy var imagePickerButton = ChatBarButton(
        sfSymbolName: "photo.fill",
        accessibilityLabel: #localize("compose_bar_image_picker_button_accessibility_label"),
        defaultColor: { Colors.backgroundChatBarButton }
    ) { [weak self] _ in
        guard let strongSelf = self else {
            return
        }
        
        if strongSelf.chatBarViewDelegate?.canSendText() ?? false {
            strongSelf.chatBarViewDelegate?.showImagePicker()
        }
    }
    
    private lazy var bottomHairlineView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()
    
    // MARK: - Lifecycle
    
    init(
        conversation: ConversationEntity,
        mentionsDelegate: MentionsTableViewDelegate,
        precomposedText: String? = nil
    ) {
        self.conversation = conversation
        self.precomposedText = precomposedText
        
        super.init(frame: .zero)
        
        configureLayout()
        
        // This should give an effect similar to the one in the tab bar
        backgroundColor = .clear
        
        chatTextView.chatTextViewDelegate = self
        chatTextView.mentionsTableViewDelegate = mentionsDelegate
        chatTextView.alwaysBounceVertical = true
        
        if precomposedText != nil {
            showSendButton()
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        DDLogVerbose("\(#function)")
    }
    
    // MARK: - Configuration
    
    private func configureLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        
        // show picker if camera is not available or we have no access
        cameraButton.isHidden = !UIImagePickerController.isSourceTypeAvailable(.camera) || AVCaptureDevice
            .authorizationStatus(for: .video) == .denied
        imagePickerButton.isHidden = !cameraButton.isHidden
        
        // Hairlines
        
        // We add one at the bottom for iPads
        if UIDevice.current.userInterfaceIdiom == .pad {
            addSubview(bottomHairlineView)
            bottomHairlineView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bottomHairlineView.leadingAnchor.constraint(equalTo: leadingAnchor),
                bottomHairlineView.bottomAnchor.constraint(equalTo: bottomAnchor),
                bottomHairlineView.trailingAnchor.constraint(equalTo: trailingAnchor),
                bottomHairlineView.heightAnchor.constraint(equalToConstant: 0.5 / UIScreen.main.scale),
            ])
        }

        // Buttons should be centered next to a single line text field. To achieve this we dynamically update the
        // centerYAnchor constraint for these buttons whenever the height of the text field changes
        
        // Plus button

        addSubview(plusButton)

        plusButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            plusButton.leadingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.leadingAnchor,
                constant: Config.textInputButtonSpacing
            ),
        ])

        let plusButtonUpdatableConstraint = plusButton.centerYAnchor.constraint(
            equalTo: chatTextView.bottomAnchor,
            constant: -currentSingleLineHeight / 2
        )
        
        updatableConstraints.append((plusButtonUpdatableConstraint, 0.0))
        
        // Chat text view

        addSubview(chatTextView)
        chatTextView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chatTextView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Config.verticalChatBarTextViewDistance
            ),
            chatTextView.leadingAnchor.constraint(
                equalTo: plusButton.trailingAnchor,
                constant: Config.textInputButtonSpacing
            ),
            chatTextView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -Config.verticalChatBarTextViewDistance
            ),
            
        ])
        
        // Right buttons
        
        addSubview(rightButtonsStackView)
        
        rightButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        cameraMicButtonConstraint = rightButtonsStackView.leadingAnchor.constraint(
            equalTo: chatTextView.trailingAnchor,
            constant: Config.textInputButtonSpacing
        )
        
        NSLayoutConstraint.activate([
            rightButtonsStackView.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor
            ),
            cameraMicButtonConstraint!,
        ])
        
        let rightButtonsStackViewUpdatableConstraint = rightButtonsStackView.centerYAnchor.constraint(
            equalTo: chatTextView.bottomAnchor,
            constant: -currentSingleLineHeight / 2
        )
        updatableConstraints.append((rightButtonsStackViewUpdatableConstraint, -1.0))
        
        // SendButton
        
        addSubview(sendButton)
        
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sendButton.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor,
                constant: -Config.textInputButtonSpacing
            ),
        ])
        
        let sendButtonUpdatableConstraint = sendButton.centerYAnchor.constraint(
            equalTo: chatTextView.bottomAnchor,
            constant: -currentSingleLineHeight / 2
        )
        updatableConstraints.append((sendButtonUpdatableConstraint, 0.0))
        
        sendButtonConstraint = sendButton.leadingAnchor.constraint(
            equalTo: chatTextView.trailingAnchor,
            constant: Config.textInputButtonSpacing
        )
        
        NSLayoutConstraint.activate(updatableConstraints.map(\.constraint))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Only configure on first layout pass that matches all the requirements
        updateCenteredButtonsIfNeeded()
    }
    
    private func updateCenteredButtonsIfNeeded() {
        // A bit of safety. Unfortunately this might be 0 at the beginning even if there is (multi-line) text
        guard chatTextView.numberOfLines == 1 else {
            return
        }
        
        // Only update height if it actually changed
        let currentChatTextViewSingleLineHeight = chatTextView.contentSize.height
        guard currentSingleLineHeight != currentChatTextViewSingleLineHeight else {
            return
        }
        
        currentSingleLineHeight = currentChatTextViewSingleLineHeight
        
        let bottomOffset = currentSingleLineHeight / 2
        
        for updatableConstraint in updatableConstraints {
            updatableConstraint.constraint.constant = -bottomOffset + updatableConstraint.offset
        }
    }
    
    // MARK: - Update
        
    func updateSendButtonAccessibilityLabel(to text: String) {
        sendButton.accessibilityLabel = text
    }
    
    func updateSendButton() {
        sendButton
            .updateButton(
                with: (chatBarViewDelegate?.isEditedMessageSet() ?? false) ? "checkmark.circle.fill" :
                    "arrow.up.circle.fill"
            )
    }
    
    // MARK: - Animations
    
    private func showSendButton() {
        showOrHideRightButtonsStackView(hide: true)
    }
    
    private func hideSendButton() {
        showOrHideRightButtonsStackView(hide: false)
    }
    
    private func showOrHideRightButtonsStackView(hide: Bool) {
        updateSendButton()
        
        guard recordButton.isHidden != hide else {
            return
        }
        
        // Config
        let totalDuration = Config.ShowHideSendButtonAnimation.totalDuration
        let fadeDuration = Config.ShowHideSendButtonAnimation.fadeDuration
        let preFadeDelay = Config.ShowHideSendButtonAnimation.preFadeDelay
        
        recordButton.isHidden = hide
        sendButton.isHidden = !hide

        // show camera if camera is available and access is not denied
        if UIImagePickerController.isSourceTypeAvailable(.camera),
           AVCaptureDevice.authorizationStatus(for: .video) != .denied {
            imagePickerButton.isHidden = true
            cameraButton.isHidden = hide
        }
        else {
            cameraButton.isHidden = true
            imagePickerButton.isHidden = hide
        }
        
        cameraMicButtonConstraint?.isActive = !hide
        sendButtonConstraint?.isActive = hide
        
        let newRecordButtonAlpha: CGFloat = hide ? 0.0 : 1.0
        let newCameraButtonAlpha: CGFloat = newRecordButtonAlpha
        let newImagePickerButtonAlpha: CGFloat = newRecordButtonAlpha
        var newSendButtonAlpha: CGFloat = !hide ? 0.0 : 1.0
        
        // Hide the “Send” button when the VoiceMessageRecorderView is in use.
        // The VoiceMessageRecorderView has a dedicated “Send” button.
        if voiceMessageController != nil {
            newSendButtonAlpha = 0.0
        }
        
        UIView.animate(
            withDuration: totalDuration,
            delay: 0.0,
            options: [.beginFromCurrentState, .curveEaseInOut],
            animations: { [weak self] in
                self?.setNeedsLayout()
                self?.layoutIfNeeded()
            }
        )
        UIView.animate(
            withDuration: fadeDuration,
            delay: preFadeDelay + (totalDuration - fadeDuration),
            options: [.beginFromCurrentState, .curveEaseInOut],
            animations: { [weak self] in
                self?.recordButton.alpha = newRecordButtonAlpha
                self?.cameraButton.alpha = newCameraButtonAlpha
                self?.imagePickerButton.alpha = newImagePickerButtonAlpha
                self?.sendButton.alpha = newSendButtonAlpha
            }
        )
    }
    
    // MARK: - Public Functions
    
    public func getCurrentText() -> String? {
        chatTextView.getCurrentText()
    }
    
    public func setCurrentText(_ text: String) {
        chatTextView.setCurrentText(text)
        chatTextViewDidChange(chatTextView, changeTyping: false)
    }

    public func removeCurrentText() {
        chatTextView.removeCurrentText()
        chatTextViewDidChange(chatTextView, changeTyping: false)
    }

    public func saveVoiceMessageRecordingAsDraft() {
        voiceMessageController?.saveVoiceMessageRecordingAsDraft()
    }
    
    public var recordingState: RecordingState {
        voiceMessageController?.recordingState ?? .ready
    }

    /// Resets the keyboard to the default keyboard
    @MainActor
    public func resetKeyboard() {
        chatTextView.keyboardType = .default
        chatTextView.reloadInputViews()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        chatTextView.resignFirstResponder()
        return super.resignFirstResponder()
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        chatTextView.becomeFirstResponder()
    }
    
    /// Sends endEditing to the textView
    public func endEditing() {
        chatTextView.endEditing(true)
    }
    
    /// Should be called to reformat the currently editing mention
    /// - Parameter identity: the mentioned identity
    public func mentionSelected(identity: String) {
        chatTextView.mentionsTableViewHasSelected(identity: identity)
    }
    
    /// Invalidate all typing timers
    public func stopTypingTimer() {
        typingTimer?.invalidate()
        typingTimer = nil
        continueTypingTimer?.invalidate()
        continueTypingTimer = nil
    }
    
    public func enablePlusButton() {
        plusButton.isEnabled = true
    }
    
    public func disablePlusButton() {
        plusButton.isEnabled = false
    }
}

// MARK: - ChatTextViewDelegate

extension ChatBarView: ChatTextViewDelegate {
    func chatTextViewDidChange(_ textView: ChatTextView) {
        chatTextViewDidChange(textView, changeTyping: true)
        chatBarViewDelegate?.updateLayoutForTextChange()
    }
    
    func didEndEditing() {
        // Send stop typing indicator
        if isTyping {
            sendStartOrStopTypingIndicator()
        }
    }
    
    func sendText() {
        // Ensure last auto correction is applied
        chatTextView.inputDelegate?.selectionWillChange(chatTextView)
        chatTextView.inputDelegate?.selectionDidChange(chatTextView)
        
        guard let chatBarViewDelegate else {
            assertionFailure("chatBarViewDelegate must not be nil when sending a text")
            return
        }

        guard let text = getCurrentText(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Switch back to default keyboard (in case we're currently using the numeric or emoji keypad)
        resetKeyboard()
        
        sendStartOrStopTypingIndicator()
        
        chatBarViewDelegate.sendText(rawText: text)
        
        if UserSettings.shared().sendMessageFeedback {
            feedbackGenerator.prepare()
            feedbackGenerator.notificationOccurred(.success)
        }
    }
    
    func canStartEditing() -> Bool {
        chatBarViewDelegate?.canSendText() ?? false
    }
    
    func showContact(identity: String) {
        chatBarViewDelegate?.showContact(identity: identity)
    }

    /// This flips the isTyping indicator and sends a message updating the status for the contact
    /// Additionally we keep track of time and stop the typing indicator after 5 seconds.
    private func sendStartOrStopTypingIndicator() {
        if continueTypingTimer == nil {
            continueTypingTimer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(TypingIndicatorManager.typingIndicatorResendInterval()),
                repeats: false,
                block: { [weak self] _ in
                    if let isTyping = self?.isTyping, isTyping {
                        self?.chatBarViewDelegate?.sendTypingIndicator(startTyping: isTyping)
                    }
                }
            )
        }
        
        // Send typing indicator
        // Restart timer to send stop typing
        if let timer = typingTimer {
            timer.invalidate()
            typingTimer = nil
        }
        
        typingTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(TypingIndicatorManager.typingIndicatorTypingPauseInterval()),
            repeats: false,
            block: { _ in
                self.isTyping = false
                self.chatBarViewDelegate?.sendTypingIndicator(startTyping: self.isTyping)
            }
        )
        
        DDLogVerbose(
            "Should change \(isTyping != chatTextView.isEditing) isTyping \(isTyping) chatTextView.isEditing \(chatTextView.isEditing)"
        )
        guard isTyping != chatTextView.isEditing else {
            return
        }
        
        if !isTyping {
            isTyping = true
            chatBarViewDelegate?.sendTypingIndicator(startTyping: isTyping)
        }
        else {
            isTyping = false
            chatBarViewDelegate?.sendTypingIndicator(startTyping: isTyping)
        }
    }
    
    func checkIfPastedStringIsMedia() -> Bool {
        chatBarViewDelegate?.checkIfPastedStringIsMedia() ?? false
    }
    
    @available(iOS 18.0, *)
    func processAndSendGlyph(_ glyph: NSAdaptiveImageGlyph) {
        chatBarViewDelegate?.processAndSendGlyph(glyph)
    }
    
    // MARK: ChatTextViewDelegate Helpers
    
    private func chatTextViewDidChange(_ textView: ChatTextView, changeTyping: Bool = true) {
        if chatTextView.isEmpty {
            hideSendButton()
        }
        else {
            showSendButton()
        }
        
        if changeTyping {
            sendStartOrStopTypingIndicator()
        }
    }
}

// MARK: - VoiceMessageRecorderView Configuration

extension ChatBarView {
    func presentVoiceMessageRecorderView(
        with delegate: VoiceMessageRecorderViewDelegate?,
        with draftAudioURL: URL? = nil
    ) {
        let model: VoiceMessageRecorderViewModel
        do {
            model = try VoiceMessageRecorderViewModel(conversation: conversation, draftAudioURL: draftAudioURL)
        }
        catch {
            return
        }
        
        let recorderViewController = VoiceMessageRecorderView.make(
            to: self,
            with: delegate,
            model: model
        )
        recorderViewController.view.alpha = 0
        sendButton.alpha = 0
        plusButton.alpha = 0
        
        addSubview(recorderViewController.view)
        
        NSLayoutConstraint.activate([
            recorderViewController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            recorderViewController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            recorderViewController.view.topAnchor.constraint(equalTo: topAnchor),
            recorderViewController.view.centerYAnchor.constraint(equalTo: centerYAnchor),
            recorderViewController.view.widthAnchor.constraint(equalTo: widthAnchor),
        ])
        chatTextView.isEditable = false
        voiceMessageController = recorderViewController
        showRecorder(animated: draftAudioURL == nil)
    }
    
    func dismissVoiceMessageRecorderView() {
        chatTextView.isEditable = true
        sendButton.alpha = 1
        plusButton.alpha = 1
        hideSendButton()
        hideRecorder()
    }
    
    private func showRecorder(animated: Bool = true) {
        if animated {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        let show = { [weak self] in
            self?.voiceMessageController?.view.alpha = 1
            self?.chatTextView.alpha = 0
            self?.showSendButton()
        }
        
        guard animated else {
            return show()
        }
        
        let totalDuration = Config.ShowHideSendButtonAnimation.totalDuration
        let fadeDuration = Config.ShowHideSendButtonAnimation.fadeDuration
        let preFadeDelay = Config.ShowHideSendButtonAnimation.preFadeDelay
 
        UIView.animate(
            withDuration: fadeDuration,
            delay: preFadeDelay + (totalDuration - fadeDuration),
            options: [.beginFromCurrentState, .curveEaseInOut],
            animations: show
        )
    }
    
    private func hideRecorder() {
        UIView.animate(
            withDuration: Config.ShowHideSendButtonAnimation.fadeDuration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut]
        ) {
            [weak self] in
            self?.voiceMessageController?.view.alpha = 0
            self?.chatTextView.alpha = 1
        } completion: { [weak self] _ in
            self?.voiceMessageController?.view.removeFromSuperview()
            self?.voiceMessageController = nil
            if !(self?.chatTextView.isEmpty ?? true) {
                self?.showSendButton()
            }
        }
    }
}
