import CocoaLumberjackSwift
import Foundation
import SwiftUI
import ThreemaFramework
import ThreemaMacros
import UIKit

final class ChatBarView: UIView {

    // MARK: - Private types

    private typealias Config = ChatBarConfiguration
    private typealias UpdatableConstraint = (constraint: NSLayoutConstraint, offset: CGFloat)

    // MARK: - Internal Properties

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

    // MARK: Views

    private lazy var chatTextView: ChatTextView = {
        let chatTextView = ChatTextView(
            precomposedText: precomposedText,
            conversationIdentifier: conversation.objectID.uriRepresentation().absoluteString
        )

        chatTextView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        chatTextView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        chatTextView.semanticContentAttribute = .unspecified

        return chatTextView
    }()

    /// Wraps the `ChatTextView` in glass container.
    private(set) lazy var glassEffectChatTextView: UIView = {
        guard #available(iOS 26.0, *) else {
            assertionFailure("Do not use before iOS 26.")
            return UIView()
        }

        let glassEffect = UIGlassEffect(style: .regular)
        glassEffect.isInteractive = true

        let glassEffectView = UIVisualEffectView(effect: glassEffect)
        glassEffectView.contentView.addSubview(chatTextView)
        glassEffectView.cornerConfiguration = .uniformCorners(
            radius: UICornerRadius(floatLiteral: ChatTextViewConfiguration.cornerRadius)
        )

        chatTextView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chatTextView.topAnchor.constraint(
                equalTo: glassEffectView.contentView.topAnchor
            ),
            chatTextView.trailingAnchor.constraint(
                equalTo: glassEffectView.contentView.trailingAnchor
            ),
            chatTextView.leadingAnchor.constraint(
                equalTo: glassEffectView.contentView.leadingAnchor
            ),
            chatTextView.bottomAnchor.constraint(
                equalTo: glassEffectView.contentView.bottomAnchor
            ),
        ])

        return glassEffectView
    }()

    // MARK: Buttons

    private(set) lazy var plusButton: ChatBarButton = {
        let action = UIAction { [weak self] _ in
            guard let strongSelf = self else {
                return
            }

            if strongSelf.chatBarViewDelegate?.canSendText() ?? false {
                strongSelf.chatBarViewDelegate?.showAssetsSelector()
            }
        }

        let plusButton = ChatBarButton(
            for: .plusButton,
            action: action
        )

        plusButton.translatesAutoresizingMaskIntoConstraints = false
        plusButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        plusButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        plusButton.accessibilityIdentifier = "ChatBarViewImageButton"

        return plusButton
    }()

    private(set) lazy var sendButton: ChatBarButton = {
        let action = UIAction { [weak self] _ in
            guard
                let self,
                chatBarViewDelegate?.canSendText() == true
            else {
                return
            }

            sendText()
        }

        let sendButton = ChatBarButton(
            for: .sendButton,
            action: action
        )

        sendButton.isHidden = true
        sendButton.alpha = 0.0

        sendButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        sendButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        return sendButton
    }()

    private lazy var trailingButtonsGlassView: UIVisualEffectView = {
        guard #available(iOS 26.0, *) else {
            return UIVisualEffectView()
        }

        let glassEffect = UIGlassEffect(style: .regular)
        glassEffect.isInteractive = true

        let glassEffectView = UIVisualEffectView(effect: glassEffect)
        glassEffectView.translatesAutoresizingMaskIntoConstraints = false

        glassEffectView.contentView.addSubview(recordButton)

        glassEffectView.cornerConfiguration = .uniformCorners(
            radius: UICornerRadius(floatLiteral: ChatTextViewConfiguration.cornerRadius)
        )

        NSLayoutConstraint.activate([
            recordButton.topAnchor.constraint(
                equalTo: glassEffectView.contentView.topAnchor
            ),
            recordButton.trailingAnchor.constraint(
                equalTo: glassEffectView.contentView.trailingAnchor,
                constant: -Config.buttonTrailingLeadingSpacing
            ),
            recordButton.bottomAnchor.constraint(
                equalTo: glassEffectView.contentView.bottomAnchor
            ),
        ])

        glassEffectView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        glassEffectView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return glassEffectView
    }()

    private lazy var trailingButtonsGlassViewConstraints: [NSLayoutConstraint] = [
        trailingButtonsGlassView.leadingAnchor.constraint(
            equalTo: glassEffectChatTextView.trailingAnchor,
            constant: Config.textInputButtonSpacing
        ),
        trailingButtonsGlassView.bottomAnchor.constraint(
            equalTo: safeAreaLayoutGuide.bottomAnchor,
            constant: -Config.verticalChatBarTextViewDistance
        ),
        trailingButtonsGlassView.trailingAnchor.constraint(
            equalTo: safeAreaLayoutGuide.trailingAnchor,
            constant: -Config.textInputButtonSpacing
        ),
        trailingButtonsGlassView.heightAnchor.constraint(
            equalTo: plusButton.heightAnchor,
        ),
    ]

    private lazy var recordButton = {
        let action = UIAction { [weak self] _ in
            guard
                let self,
                chatBarViewDelegate?.canSendText() == true
            else {
                return
            }

            chatBarViewDelegate?.startRecording(with: nil)
        }

        let recordButton = ChatBarButton(
            for: .recordButton,
            action: action
        )

        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        return recordButton
    }()

    private lazy var cameraButtonConstraints = [
        cameraButton.topAnchor.constraint(
            equalTo: trailingButtonsGlassView.contentView.topAnchor
        ),
        cameraButton.trailingAnchor.constraint(
            equalTo: recordButton.leadingAnchor
        ),
        cameraButton.leadingAnchor.constraint(
            equalTo: trailingButtonsGlassView.contentView.leadingAnchor,
            constant: Config.buttonTrailingLeadingSpacing
        ),
        cameraButton.bottomAnchor.constraint(
            equalTo: trailingButtonsGlassView.contentView.bottomAnchor
        ),
    ]

    private lazy var cameraButton = {
        let action = UIAction { [weak self] _ in
            guard let self else {
                return
            }

            if chatBarViewDelegate?.canSendText() ?? false {
                let avCaptureDeviceStatus = AVCaptureDevice.authorizationStatus(for: .video)
                guard UIImagePickerController.isSourceTypeAvailable(.camera),
                      avCaptureDeviceStatus != .denied else {
                    // Switch camera to image picker icon
                    if #available(iOS 26.0, *) {
                        configureGlassLayout()
                    }
                    else {
                        configureOldLayout()
                    }

                    return
                }

                if avCaptureDeviceStatus == .authorized {
                    chatBarViewDelegate?.showCamera()
                }
                else {
                    AVCaptureDevice.requestAccess(for: .video) { (granted: Bool) in
                        DispatchQueue.main.async {
                            if granted {
                                self.chatBarViewDelegate?.showCamera()
                            }
                            else {
                                // Switch camera to image picker icon
                                if #available(iOS 26.0, *) {
                                    self.configureGlassLayout()
                                }
                                else {
                                    self.configureOldLayout()
                                }
                            }
                        }
                    }
                }
            }
        }

        let cameraButton = ChatBarButton(
            for: .cameraButton,
            action: action
        )

        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        cameraButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        return cameraButton
    }()

    private lazy var imagePickerButtonConstraints = [
        imagePickerButton.topAnchor.constraint(
            equalTo: trailingButtonsGlassView.contentView.topAnchor
        ),
        imagePickerButton.trailingAnchor.constraint(
            equalTo: recordButton.leadingAnchor
        ),
        imagePickerButton.leadingAnchor.constraint(
            equalTo: trailingButtonsGlassView.contentView.leadingAnchor,
            constant: -Config.buttonTrailingLeadingSpacing
        ),
        imagePickerButton.bottomAnchor.constraint(
            equalTo: trailingButtonsGlassView.contentView.bottomAnchor
        ),
    ]

    private lazy var imagePickerButton = {
        let action = UIAction { [weak self] _ in
            guard let strongSelf = self else {
                return
            }

            if strongSelf.chatBarViewDelegate?.canSendText() ?? false {
                strongSelf.chatBarViewDelegate?.showImagePicker()
            }
        }

        let imagePickerButton = ChatBarButton(
            for: .imagePickerButton,
            action: action
        )

        imagePickerButton.translatesAutoresizingMaskIntoConstraints = false
        imagePickerButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        return imagePickerButton
    }()

    // MARK: Pre iOS 26

    private(set) lazy var oldPlusButton: Old_ChatBarButton = {
        let imageButton = Old_ChatBarButton(
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

    private lazy var oldSendButton: Old_ChatBarButton = {
        let imageButton = Old_ChatBarButton(
            sfSymbolName: "arrow.up.circle.fill",
            accessibilityLabel: #localize("compose_bar_send_message_button_accessibility_label"),
            defaultColor: { .tintColor },
            customScalableSize: Config.sendButtonSize
        ) { [weak self] _ in
            guard
                let self,
                chatBarViewDelegate?.canSendText() == true
            else {
                return
            }

            sendText()
        }

        imageButton.isHidden = true
        imageButton.alpha = 0.0

        imageButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        return imageButton
    }()

    private lazy var oldTrailingButtonsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            oldCameraButton,
            oldImagePickerButton,
            oldRecordButton,
        ])

        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillProportionally
        stack.spacing = Config.cameraMicSpacing
        stack.semanticContentAttribute = .forceLeftToRight

        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return stack
    }()

    private lazy var oldRecordButton: Old_ChatBarButton = {
        let button = Old_ChatBarButton(
            sfSymbolName: "mic.fill",
            accessibilityLabel: #localize("compose_bar_record_button_accessibility_label"),
            defaultColor: { Colors.backgroundChatBarButton }
        ) { [weak self] _ in
            guard
                let self,
                chatBarViewDelegate?.canSendText() == true
            else {
                return
            }

            chatBarViewDelegate?.startRecording(with: nil)
        }

        let layoutDirection = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute)
        let left = layoutDirection == .leftToRight
            ? 0
            : Config.textInputButtonSpacing
        let right = layoutDirection == .leftToRight
            ? Config.textInputButtonSpacing
            : 0

        // This is deprecated but since we're not using UIButtonConfiguration anyways this doesn't matter
        button.contentEdgeInsets = UIEdgeInsets(
            top: 0,
            left: left,
            bottom: 0,
            right: right
        )

        return button
    }()

    private lazy var oldCameraButton = Old_ChatBarButton(
        sfSymbolName: "camera.fill",
        accessibilityLabel: #localize("compose_bar_camera_button_accessibility_label"),
        defaultColor: { Colors.backgroundChatBarButton }
    ) { [weak self] _ in
        guard
            let self,
            chatBarViewDelegate?.canSendText() == true
        else {
            return
        }

        let captureDeviceStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard
            UIImagePickerController.isSourceTypeAvailable(.camera),
            captureDeviceStatus != .denied
        else {
            // Switch camera to image picker icon
            if #available(iOS 26.0, *) {
                configureGlassLayout()
            }
            else {
                configureOldLayout()
            }

            return
        }

        guard captureDeviceStatus != .authorized else {
            chatBarViewDelegate?.showCamera()

            return
        }

        AVCaptureDevice.requestAccess(
            for: .video,
            completionHandler: { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.chatBarViewDelegate?.showCamera()
                    }
                    else {
                        // Switch camera to image picker icon
                        if #available(iOS 26.0, *) {
                            self?.configureGlassLayout()
                        }
                        else {
                            self?.configureOldLayout()
                        }
                    }
                }
            }
        )
    }

    private lazy var oldImagePickerButton = Old_ChatBarButton(
        sfSymbolName: "photo.fill",
        accessibilityLabel: #localize("compose_bar_image_picker_button_accessibility_label"),
        defaultColor: { Colors.backgroundChatBarButton }
    ) { [weak self] _ in
        guard
            let self,
            chatBarViewDelegate?.canSendText() == true
        else {
            return
        }

        chatBarViewDelegate?.showImagePicker()
    }

    private lazy var bottomHairlineView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    // MARK: - Superview overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        // Only configure on first layout pass that matches all the requirements
        updateCenteredButtonsIfNeeded()
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

    /// The chat bar should *always* be laid out left-to-right, even when using
    /// a right-to-left language. The convention for messaging apps is for the send
    /// button to always be to the right of the input field, even in RTL layouts.
    /// This matches the behavior of e.g. WhatsApp, Telegram, and Messages.
    /// Set the appropriate `semanticContentAttribute` to ensure horizontal
    /// stack views layout left-to-right.
    override var semanticContentAttribute: UISemanticContentAttribute {
        get { .forceLeftToRight }
        set { }
    }

    // MARK: - Lifecycle

    init(
        conversation: ConversationEntity,
        mentionsDelegate: MentionsTableViewDelegate,
        precomposedText: String? = nil
    ) {
        self.conversation = conversation
        self.precomposedText = precomposedText

        super.init(frame: .zero)

        if #available(iOS 26.0, *) {
            configureGlassLayout()
        }
        else {
            configureOldLayout()
        }

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

    // MARK: - Internal methods

    func updateSendButtonAccessibilityLabel(to text: String) {
        if #available(iOS 26.0, *) {
            sendButton.accessibilityLabel = text
        }
        else {
            oldSendButton.accessibilityLabel = text
        }
    }

    func updateSendButton() {
        if #available(iOS 26.0, *) {
            sendButton.updateImage(
                imageName: (chatBarViewDelegate?.isEditedMessageSet() ?? false) ? "checkmark" :
                    "arrow.up"
            )
        }
        else {
            oldSendButton.updateButton(
                with:
                (chatBarViewDelegate?.isEditedMessageSet() ?? false) ? "checkmark.circle.fill" :
                    "arrow.up.circle.fill"
            )
        }
    }

    func toggleBarButtons(enabled: Bool) {
        if #available(iOS 26.0, *) {
            plusButton.isEnabled = enabled
            imagePickerButton.isEnabled = enabled
            cameraButton.isEnabled = enabled
            recordButton.isEnabled = enabled
        }
        else {
            oldPlusButton.isEnabled = enabled
            oldImagePickerButton.isEnabled = enabled
            oldCameraButton.isEnabled = enabled
            oldRecordButton.isEnabled = enabled
        }
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
        if #available(iOS 26.0, *) {
            plusButton.isEnabled = true
        }
        else {
            oldPlusButton.isEnabled = true
        }
    }

    public func disablePlusButton() {
        if #available(iOS 26.0, *) {
            plusButton.isEnabled = false
        }
        else {
            oldPlusButton.isEnabled = false
        }
    }

    // MARK: - Private methods

    private var topViewController: UIViewController {
        guard var topVC = window?.rootViewController else {
            let errorMessage = "Expected a valid root view controller of the main window, but got nil instead."
            assertionFailure(errorMessage)
            DDLogError("\(errorMessage)")
            return UIViewController()
        }
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }

    private func scanQRCode(sender chatTextView: ChatTextView) {
        let model = QRCodeScannerViewModel(
            mode: .plainText,
            audioSessionManager: AudioSessionManager(),
            systemFeedbackManager: SystemFeedbackManager(
                deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                settingsStore: BusinessInjector.ui.settingsStore
            ),
            systemPermissionsManager: SystemPermissionsManager()
        )

        model.onCompletion = { [weak self] result in
            guard let self, case let .plainText(text) = result else {
                return
            }
            topViewController.dismiss(animated: true) { [chatTextView] in
                chatTextView.insertText(text)
            }
        }

        model.onCancel = { [weak self] in
            self?.topViewController.dismiss(animated: true)
        }

        let rootView = QRCodeScannerView(model: model)
        let viewController = UIHostingController(rootView: rootView)
        let nav = PortraitNavigationController(rootViewController: viewController)

        topViewController.present(nav, animated: true)
    }

    /// This flips the isTyping indicator and sends a message updating the status for the contact
    /// Additionally we keep track of time and stop the typing indicator after 5 seconds.
    private func sendStartOrStopTypingIndicator() {
        if continueTypingTimer == nil {
            continueTypingTimer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(TypingIndicatorManager.typingIndicatorResendInterval()),
                repeats: false,
                block: { [weak self, isTyping] _ in
                    guard let self, isTyping else {
                        return
                    }
                    chatBarViewDelegate?.sendTypingIndicator(startTyping: isTyping)
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

    private func showSendButton() {
        showOrHideTrailingButtonsStackView(hide: true)
    }

    private func hideSendButton() {
        showOrHideTrailingButtonsStackView(hide: false)
    }

    private func showOrHideTrailingButtonsStackView(hide: Bool) {
        updateSendButton()

        // Config
        let totalDuration = Config.ShowHideSendButtonAnimation.totalDuration
        let fadeDuration = Config.ShowHideSendButtonAnimation.fadeDuration
        let preFadeDelay = Config.ShowHideSendButtonAnimation.preFadeDelay

        if #available(iOS 26.0, *) {
            showOrHideTrailingButtonsGlassView(hide: hide)
            showOrHideCameraButton()
            sendButton.isHidden = !hide
        }
        else {
            guard oldRecordButton.isHidden != hide else {
                return
            }

            oldSendButton.isHidden = !hide
            oldRecordButton.isHidden = hide

            // Show camera if camera is available and access is not denied
            if UIImagePickerController.isSourceTypeAvailable(.camera),
               AVCaptureDevice.authorizationStatus(for: .video) != .denied {
                oldImagePickerButton.isHidden = true
                oldCameraButton.isHidden = hide
            }
            else {
                oldCameraButton.isHidden = true
                oldImagePickerButton.isHidden = hide
            }
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
                if #available(iOS 26.0, *) {
                    self?.recordButton.alpha = newRecordButtonAlpha
                    self?.cameraButton.alpha = newCameraButtonAlpha
                    self?.imagePickerButton.alpha = newImagePickerButtonAlpha
                    self?.sendButton.alpha = newSendButtonAlpha
                }
                else {
                    self?.oldRecordButton.alpha = newRecordButtonAlpha
                    self?.oldCameraButton.alpha = newCameraButtonAlpha
                    self?.oldImagePickerButton.alpha = newImagePickerButtonAlpha
                    self?.oldSendButton.alpha = newSendButtonAlpha
                }
            }
        )
    }

    @available(iOS 26.0, *)
    private func showOrHideTrailingButtonsGlassView(hide: Bool) {
        if hide {
            trailingButtonsGlassView.removeFromSuperview()
        }
        else {
            addSubview(trailingButtonsGlassView)
            NSLayoutConstraint.activate(trailingButtonsGlassViewConstraints)
        }
    }

    @available(iOS 26.0, *)
    private func showOrHideCameraButton() {
        // Show camera if camera is available and access is not denied
        if UIImagePickerController.isSourceTypeAvailable(.camera),
           AVCaptureDevice.authorizationStatus(for: .video) != .denied {
            imagePickerButton.removeFromSuperview()
            NSLayoutConstraint.deactivate(imagePickerButtonConstraints)

            trailingButtonsGlassView.contentView.addSubview(cameraButton)
            NSLayoutConstraint.activate(cameraButtonConstraints)
        }
        else {
            cameraButton.removeFromSuperview()
            NSLayoutConstraint.deactivate(cameraButtonConstraints)

            trailingButtonsGlassView.contentView.addSubview(imagePickerButton)
            NSLayoutConstraint.activate(imagePickerButtonConstraints)
        }
    }

    private func configureGlassLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        // Buttons should be centered next to a single line text field. To achieve this we dynamically update the
        // centerYAnchor constraint for these buttons whenever the height of the text field changes

        // Plus button
        addSubview(plusButton)

        NSLayoutConstraint.activate([
            plusButton.leadingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.leadingAnchor,
                constant: Config.textInputButtonSpacing
            ),
            plusButton.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -Config.verticalChatBarTextViewDistance
            ),
            plusButton.widthAnchor.constraint(
                equalTo: plusButton.heightAnchor,
            ),
        ])

        let plusButtonUpdatableConstraint =
            plusButton.centerYAnchor.constraint(
                equalTo: chatTextView.bottomAnchor,
                constant: -currentSingleLineHeight / 2
            )

        updatableConstraints.append((plusButtonUpdatableConstraint, 0.0))

        // Chat text view
        addSubview(glassEffectChatTextView)
        glassEffectChatTextView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            glassEffectChatTextView.topAnchor.constraint(
                equalTo: topAnchor
            ),
            glassEffectChatTextView.leadingAnchor.constraint(
                equalTo: plusButton.trailingAnchor,
                constant: Config.textInputButtonSpacing
            ),
            glassEffectChatTextView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -Config.verticalChatBarTextViewDistance
            ),
        ])

        // Right buttons
        addSubview(trailingButtonsGlassView)

        // Show picker if camera is not available or we have no access
        let showCameraButton = UIImagePickerController.isSourceTypeAvailable(.camera) &&
            AVCaptureDevice.authorizationStatus(for: .video) != .denied

        if showCameraButton {
            trailingButtonsGlassView.contentView.addSubview(cameraButton)
            NSLayoutConstraint.activate(cameraButtonConstraints)
        }
        else {
            trailingButtonsGlassView.contentView.addSubview(imagePickerButton)
            NSLayoutConstraint.activate(imagePickerButtonConstraints)
        }

        NSLayoutConstraint.activate(trailingButtonsGlassViewConstraints)

        let rightStackUpdatableConstraint =
            trailingButtonsGlassView.centerYAnchor.constraint(
                equalTo: chatTextView.bottomAnchor,
                constant: -currentSingleLineHeight / 2
            )
        updatableConstraints.append((rightStackUpdatableConstraint, 0.0))

        // SendButton
        addSubview(sendButton)

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sendButton.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor,
                constant: -Config.textInputButtonSpacing
            ),
            sendButton.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -Config.verticalChatBarTextViewDistance
            ),
            sendButton.widthAnchor.constraint(
                equalTo: sendButton.heightAnchor,
            ),
        ])

        let sendButtonUpdatableConstraint = sendButton.centerYAnchor.constraint(
            equalTo: chatTextView.bottomAnchor,
            constant: -currentSingleLineHeight / 2
        )
        updatableConstraints.append((sendButtonUpdatableConstraint, 0.0))

        sendButtonConstraint = sendButton.leadingAnchor.constraint(
            equalTo: glassEffectChatTextView.trailingAnchor,
            constant: Config.textInputButtonSpacing
        )

        NSLayoutConstraint.activate(updatableConstraints.map(\.constraint))
    }

    private func configureOldLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        // show picker if camera is not available or we have no access
        oldCameraButton.isHidden = !UIImagePickerController.isSourceTypeAvailable(.camera) || AVCaptureDevice
            .authorizationStatus(for: .video) == .denied
        oldImagePickerButton.isHidden = !oldCameraButton.isHidden

        // Hairlines

        // We add one at the bottom for iPads
        if traitCollection.horizontalSizeClass == .regular {
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

        addSubview(oldPlusButton)

        oldPlusButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            oldPlusButton.leadingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.leadingAnchor,
                constant: Config.textInputButtonSpacing
            ),
        ])

        let plusButtonUpdatableConstraint = oldPlusButton.centerYAnchor.constraint(
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
                equalTo: oldPlusButton.trailingAnchor,
                constant: Config.textInputButtonSpacing
            ),
            chatTextView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -Config.verticalChatBarTextViewDistance
            ),
        ])

        // Right buttons

        addSubview(oldTrailingButtonsStackView)

        cameraMicButtonConstraint = oldTrailingButtonsStackView.leadingAnchor.constraint(
            equalTo: chatTextView.trailingAnchor,
            constant: Config.textInputButtonSpacing
        )

        NSLayoutConstraint.activate([
            oldTrailingButtonsStackView.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor
            ),
            cameraMicButtonConstraint!,
        ])

        let oldTrailingButtonsStackViewUpdatableConstraint = oldTrailingButtonsStackView.centerYAnchor.constraint(
            equalTo: chatTextView.bottomAnchor,
            constant: -currentSingleLineHeight / 2
        )
        updatableConstraints.append((oldTrailingButtonsStackViewUpdatableConstraint, -1.0))

        // SendButton

        addSubview(oldSendButton)

        oldSendButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            oldSendButton.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor,
                constant: -Config.textInputButtonSpacing
            ),
        ])

        let sendButtonUpdatableConstraint = oldSendButton.centerYAnchor.constraint(
            equalTo: chatTextView.bottomAnchor,
            constant: -currentSingleLineHeight / 2
        )
        updatableConstraints.append((sendButtonUpdatableConstraint, 0.0))

        sendButtonConstraint = oldSendButton.leadingAnchor.constraint(
            equalTo: chatTextView.trailingAnchor,
            constant: Config.textInputButtonSpacing
        )

        NSLayoutConstraint.activate(updatableConstraints.map(\.constraint))
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
}

// MARK: - ChatTextViewDelegate

extension ChatBarView: ChatTextViewDelegate {
    func chatTextViewDidChange(_ textView: ChatTextView) {
        chatTextViewDidChange(textView, changeTyping: true)
        chatBarViewDelegate?.updateLayoutForTextChange()
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

    func didEndEditing() {
        // Send stop typing indicator
        if isTyping {
            sendStartOrStopTypingIndicator()
        }
    }

    func checkIfPastedStringIsMedia() -> Bool {
        chatBarViewDelegate?.checkIfPastedStringIsMedia() ?? false
    }
    
    @available(iOS 18.0, *)
    func processAndSendGlyph(_ glyph: NSAdaptiveImageGlyph) {
        chatBarViewDelegate?.processAndSendGlyph(glyph)
    }

    func textView(
        _ textView: ChatTextView,
        primaryActionFor textItem: UITextItem,
        defaultAction: UIAction
    ) -> UIAction? {
        switch textItem.content {
        case let .link(url):
            guard IDNASafetyHelper.isLegalURL(url: url, viewController: topViewController) else {
                return nil
            }

            if url.absoluteString.starts(with: "ThreemaId:") {
                return UIAction(title: defaultAction.title, image: defaultAction.image) { [weak self] _ in
                    let threemaID = String(url.absoluteString.suffix(8))
                    self?.chatBarViewDelegate?.showContact(identity: threemaID)
                }
            }

            if url.scheme == "http" || url.scheme == "https",
               url.host?.lowercased() == "threema.id" {
                return UIAction(title: defaultAction.title, image: defaultAction.image) { _ in
                    URLHandler().handle(url)
                }
            }

            return nil
        default:
            return nil
        }
    }

    func textView(
        _ textView: ChatTextView,
        editMenuFor textRange: UITextRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        guard DeviceCapabilitiesManager().supportsRecordingVideo else {
            return UIMenu(children: suggestedActions)
        }

        let scanAction = UIAction(title: #localize("scan_qr")) { [weak self] _ in
            self?.scanQRCode(sender: textView)
        }

        return UIMenu(children: suggestedActions + [scanAction])
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

        if #available(iOS 26.0, *) {
            UIView.performWithoutAnimation {
                sendButton.alpha = 0
                plusButton.alpha = 0
                glassEffectChatTextView.alpha = 0
            }
        }
        else {
            oldSendButton.alpha = 0
            oldPlusButton.alpha = 0
        }

        addSubview(recorderViewController.view)
        
        if #available(iOS 26.0, *) {
            NSLayoutConstraint.activate([
                recorderViewController.view.leadingAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: Config.textInputButtonSpacing / 2
                ),
                recorderViewController.view.trailingAnchor.constraint(
                    equalTo: safeAreaLayoutGuide.trailingAnchor,
                    constant: -Config.textInputButtonSpacing
                ),
                recorderViewController.view.topAnchor.constraint(equalTo: topAnchor),
                recorderViewController.view.centerYAnchor.constraint(equalTo: glassEffectChatTextView.centerYAnchor),
            ])
        }
        else {
            NSLayoutConstraint.activate([
                recorderViewController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
                recorderViewController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
                recorderViewController.view.topAnchor.constraint(equalTo: topAnchor),
                recorderViewController.view.centerYAnchor.constraint(equalTo: centerYAnchor),
                recorderViewController.view.widthAnchor.constraint(equalTo: widthAnchor),
            ])
        }
        
        chatTextView.isEditable = false
        voiceMessageController = recorderViewController
        showRecorder(animated: draftAudioURL == nil)
    }

    func dismissVoiceMessageRecorderView() {
        chatTextView.isEditable = true

        if #available(iOS 26.0, *) {
            UIView.performWithoutAnimation {
                sendButton.alpha = 1
                plusButton.alpha = 1
                glassEffectChatTextView.alpha = 1
            }
        }
        else {
            oldSendButton.alpha = 1
            oldPlusButton.alpha = 1
        }

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
        ) { [weak self] in
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
