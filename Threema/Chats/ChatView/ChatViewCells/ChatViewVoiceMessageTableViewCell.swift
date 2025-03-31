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

/// Display a location message
final class ChatViewVoiceMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {
    typealias config = ChatViewConfiguration.VoiceMessage
    
    static var sizingCell = ChatViewVoiceMessageTableViewCell()
    
    // MARK: - Properties
    
    /// Location message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var voiceMessageAndNeighbors: (message: VoiceMessage, neighbors: ChatViewDataSource.MessageNeighbors)? {
        didSet {
            updateCell(for: voiceMessageAndNeighbors?.message)
            
            super.setMessage(to: voiceMessageAndNeighbors?.message, with: voiceMessageAndNeighbors?.neighbors)
            
            // We only auto sync when the message actually changes
            // to improve performance and remove infinite loops
            if voiceMessageAndNeighbors?.message.objectID != oldValue?.message.objectID {
                autoSyncBlobs(with: voiceMessageAndNeighbors?.message)
            }
        }
    }
    
    weak var voiceMessageCellDelegate: ChatViewTableViewVoiceMessageCellDelegateProtocol? {
        didSet {
            waveformView.delegate = voiceMessageCellDelegate
            
            if let voiceMessageCellDelegate,
               let voiceMessage = voiceMessageAndNeighbors?.message,
               voiceMessageCellDelegate.isMessageCurrentlyPlaying(voiceMessage) {
                voiceMessageCellDelegate.reregisterCallbacks(
                    message: voiceMessage,
                    progressCallback: handleProgressCallback,
                    pauseCallback: handlePauseCallback,
                    finishedCallback: handleFinishedCallback
                )
                
                isPlaying = true
            }
            else {
                isPlaying = false
            }
        }
    }
    
    var isPlaying = false {
        didSet {
            stateButton.isPlaying = isPlaying
            micIconOrPlaybackSpeedButton.isPlaying = isPlaying
        }
    }
    
    override var bubbleWidthRatio: Double {
        ChatViewConfiguration.ChatBubble.voiceMessageCellMaxWidthRatio
    }
    
    // MARK: - Private Properties
    
    private weak var userSettings = BusinessInjector.ui.userSettings
    
    private var showsRemaining: Bool {
        set {
            userSettings?.voiceMessagesShowTimeRemaining = newValue
            updateMessageMetadataFileSizeLabel(voiceMessage: voiceMessageAndNeighbors?.message)
        }
        get {
            userSettings?.voiceMessagesShowTimeRemaining ?? false
        }
    }
    
    private var timePrefix: String {
        showsRemaining ? "-" : " "
    }
    
    private lazy var fileSizeFormatter = ByteCountFormatter()
    private lazy var progressFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()
    
    // MARK: - Views
    
    // For now we don't use a fixed number width font as it looked good in our tests
    private lazy var fileSizeLabel: MessageMetadataTextLabel = {
        let label = MessageMetadataTextLabel()
        label.textAlignment = .right
        label.font = ChatViewConfiguration.MessageMetadata.monospacedDigitFont()
        label.textColor = .secondaryLabel
        
        return label
    }()
    
    private lazy var spacerView: UIView = {
        let spacerView = UIView()
        
        let spacerViewWidthConstraint = spacerView.widthAnchor.constraint(equalToConstant: .greatestFiniteMagnitude)
        spacerViewWidthConstraint.priority = .defaultLow
        spacerViewWidthConstraint.isActive = true
        
        return spacerView
    }()
    
    // Added during up- and download to get a fixed width (with numbers up to 100%)
    private lazy var fileSizeSizingLabel: MessageMetadataTextLabel = {
        let label = MessageMetadataTextLabel()
        label.textAlignment = .right
        label.font = ChatViewConfiguration.MessageMetadata.monospacedDigitFont()
        
        return label
    }()
    
    private lazy var inlineDateAndStateView: MessageDateAndStateView = {
        let dateAndStateView = MessageDateAndStateView()
        dateAndStateView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return dateAndStateView
    }()
    
    private lazy var metadataStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            fileSizeLabel,
            spacerView,
            inlineDateAndStateView,
        ])
        
        stackView.axis = .horizontal
        stackView.alignment = .firstBaseline
        stackView.spacing = ChatViewConfiguration.File.minFileSizeAndDateAndStateSpace
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .trailing
        }
        
        return stackView
    }()
    
    private lazy var waveformView: MessageVoiceMessageWaveformView = { [weak self] in
        let view = MessageVoiceMessageWaveformView(waveformDelegate: self)
        view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(lessThanOrEqualToConstant: ChatViewConfiguration.VoiceMessage.waveformHeight),
        ])
        
        accessibilityTraits = .allowsDirectInteraction
        return view
    }()
    
    private lazy var micIconOrPlaybackSpeedButton: MessageVoiceMessageSpeedButton = {
        let button = MessageVoiceMessageSpeedButton(action: { [weak self] themedButton in
            guard let self, let speedIconButton = themedButton as? MessageVoiceMessageSpeedButton else {
                let msg = "Wrong kind of button"
                assertionFailure(msg)
                DDLogError(msg)
                return
            }
            
            guard isPlaying else {
                return
            }
            
            Task {
                let newSpeedSetting = UserSettings.shared().threemaAudioMessagePlaySpeedSwitchToNextValue()
                speedIconButton.toggleOrUpdateView()
                self.voiceMessageCellDelegate?.updatePlaybackSpeed(newSpeedSetting)
            }
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.isPlaying = false
        button.isConsumed = false
        
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        button.accessibilityHint = #localize("accessibility_voiceMessage_speed_hint")
        button.accessibilityTraits = .button

        return button
    }()
    
    private lazy var rightSideContentStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            waveformView,
            micIconOrPlaybackSpeedButton,
        ])
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = config.waveformSpeedIconStackViewSpacing
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .center
        }
        
        return stackView
    }()
    
    private lazy var mainContentStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            rightSideContentStack,
            metadataStack,
        ])
        
        stackView.axis = .vertical
        stackView.spacing = ChatViewConfiguration.Content.contentAndMetadataSpace
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .trailing
        }
        
        return stackView
    }()
        
    private lazy var contentStack: DefaultMessageContentStackView = {
        let stackView = DefaultMessageContentStackView(arrangedSubviews: [
            stateButton,
            mainContentStack,
        ])
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis = .horizontal
        stackView.spacing = ChatViewConfiguration.File.minFileSizeAndDateAndStateSpace
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .center
        }
        
        return stackView
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        
        // This adds the margin to the chat bubble border
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: -ChatViewConfiguration.Content.defaultTopBottomInset,
            leading: -ChatViewConfiguration.Content.defaultLeadingTrailingInset,
            bottom: -ChatViewConfiguration.Content.defaultTopBottomInset,
            trailing: -ChatViewConfiguration.Content.defaultLeadingTrailingInset
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // If VoiceOver is running, we hide all internal components and rely on a gesture recognizer to play and pause
        // and for speed change, and we add a custom a11y action below
        if UIAccessibility.isVoiceOverRunning {
            let tapGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tapGestureRecognizer.minimumPressDuration = 0.0
            tapGestureRecognizer.delegate = self
            view.addGestureRecognizer(tapGestureRecognizer)
            view.accessibilityElementsHidden = true
        }
        
        return view
    }()

    private lazy var contentStackViewConstraints: [NSLayoutConstraint] = [
        contentStack.topAnchor.constraint(equalTo: containerView.topAnchor),
        contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        contentStackViewNoCaptionBottomConstraint,
        contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
    ]
    
    // These are only shown if there is a caption...
    private lazy var captionTextLabel = MessageTextView(messageTextViewDelegate: self)
    private lazy var captionDateAndStateView = MessageDateAndStateView()
    private lazy var captionStack = DefaultMessageContentStackView(arrangedSubviews: [
        captionTextLabel,
        captionDateAndStateView,
    ])
    
    private lazy var captionStackViewConstraints: [NSLayoutConstraint] = [
        captionStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        captionStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        captionStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
    ]
    
    private lazy var contentStackViewCaptionBottomConstraint = contentStack.bottomAnchor.constraint(
        equalTo: captionStack.topAnchor, constant: -ChatViewConfiguration.Content.defaultTopBottomInset
    )
    private lazy var contentStackViewNoCaptionBottomConstraint = contentStack
        .bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    
    // MARK: - Internal Views
    
    lazy var stateButton: MessageVoiceMessageStateButton = { [weak self] in
        let button = MessageVoiceMessageStateButton(action: { button in
            self?.stateButtonAction(button)
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalTo: button.heightAnchor),
        ])
        
        return button
    }()
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        containerView.addSubview(contentStack)

        containerView.addSubview(fileSizeSizingLabel)
        fileSizeSizingLabel.isHidden = true
        fileSizeSizingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(captionStack)
        captionStack.isHidden = true
        captionStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate(contentStackViewConstraints)
        NSLayoutConstraint.activate(captionStackViewConstraints)
        NSLayoutConstraint.activate([
            // Connect the shown label with the sizing label
            fileSizeLabel.widthAnchor.constraint(greaterThanOrEqualTo: fileSizeSizingLabel.widthAnchor),
        ])
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleTimerDirection))
        tapGestureRecognizer.numberOfTapsRequired = 1
        fileSizeLabel.addGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer.delegate = self
        fileSizeLabel.isUserInteractionEnabled = true
        
        addObservers()
        
        super.addContent(rootView: containerView)
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredContentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Notifications
    
    @objc private func preferredContentSizeCategoryDidChange() {
        fileSizeLabel.font = ChatViewConfiguration.MessageMetadata.monospacedDigitFont()
        fileSizeSizingLabel.font = ChatViewConfiguration.MessageMetadata.monospacedDigitFont()
    }
    
    // MARK: - Updates
    
    @objc func toggleTimerDirection() {
        showsRemaining = !showsRemaining
    }
    
    override func updateColors() {
        super.updateColors()
        
        micIconOrPlaybackSpeedButton.updateColors()
        stateButton.updateColors()
    }
    
    func updateMessageMetadataFileSizeLabel(voiceMessage: VoiceMessage?) {
        guard let voiceMessage else {
            fileSizeLabel.text = ""
            return
        }
        
        if let duration = voiceMessage.durationTimeInterval {
            fileSizeLabel.text = DateFormatter.timeFormatted(Int(duration))
            fileSizeSizingLabel.text = "\(timePrefix)\(DateFormatter.timeFormatted(Int(duration)))"
        }
        else {
            fileSizeLabel.text = ByteCountFormatter().string(fromByteCount: Int64(voiceMessage.blobSize))
        }
        
        switch voiceMessage.blobDisplayState {
        case .remote, .pending, .processed, .uploaded, .sendingError:
            let duration = voiceMessage.durationTimeInterval ?? 0.0
            fileSizeLabel.text = DateFormatter.timeFormatted(Int(duration))
            fileSizeSizingLabel.text = "\(timePrefix)\(DateFormatter.timeFormatted(Int(duration)))"
            
        case let .downloading(progress: progress), let .uploading(progress: progress):
            if let progressString = progressFormatter.string(from: Double(progress) as NSNumber) {
                fileSizeLabel.text = """
                    \(fileSizeFormatter.string(for: voiceMessage.dataBlobFileSize) ?? "") \
                    (\(progressString))
                    """
            }
            else {
                fileSizeLabel.text = fileSizeFormatter.string(for: voiceMessage.dataBlobFileSize)
            }
            
            // We keep the sizing label at a constant size during up and download
            fileSizeSizingLabel.text = """
                \(fileSizeFormatter.string(for: voiceMessage.dataBlobFileSize) ?? "") \
                (\(progressFormatter.string(from: 1.0) ?? ""))
                """
            
        case .dataDeleted:
            fileSizeLabel.text = #localize("file_deleted_title")
            fileSizeSizingLabel.text = nil
            
        case .fileNotFound:
            fileSizeLabel.text = #localize("file_not_found_title")
            fileSizeSizingLabel.text = nil
        }
    }
    
    func downloadAndPlay() {
        guard let objectID = voiceMessageAndNeighbors?.message.objectID else {
            return
        }
        
        Task {
            await BlobManager.shared.autoSyncBlobs(for: objectID)
            startPlayback()
        }
    }
    
    private func updateCell(for voiceMessage: VoiceMessage?) {
        updateMessageMetadataFileSizeLabel(voiceMessage: voiceMessage)
        
        inlineDateAndStateView.message = voiceMessage
        captionDateAndStateView.message = voiceMessage
        stateButton.voiceMessage = voiceMessage
        waveformView.voiceMessage = voiceMessage
        
        if let message = voiceMessage, let voiceMessageCellDelegate {
            waveformView.updateProgressWaveform(voiceMessageCellDelegate.getProgress(for: message))
        }
        
        if let message = voiceMessage,
           !message.isOwnMessage {
            micIconOrPlaybackSpeedButton.isConsumed = message.consumed != nil
        }
        else {
            micIconOrPlaybackSpeedButton.isConsumed = true
        }
        
        if !(voiceMessage?.showDateAndStateInline ?? false) {
            captionTextLabel.text = voiceMessage?.caption
            showCaptionAndDateAndState()
        }
        else {
            hideCaptionAndDateAndState()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        if editing, isPlaying {
            pausePlayback()
        }
        
        waveformView.isUserInteractionEnabled = !editing
        stateButton.isUserInteractionEnabled = !editing
        micIconOrPlaybackSpeedButton.isUserInteractionEnabled = !editing
        fileSizeLabel.isUserInteractionEnabled = !editing
    }
    
    private func autoSyncBlobs(with message: VoiceMessage?) {
        guard let objectID = message?.objectID else {
            return
        }
        
        Task {
            await BlobManager.shared.autoSyncBlobs(for: objectID)
            waveformView.render(message)
        }
    }
    
    // MARK: - Show and hide
    
    private func showCaptionAndDateAndState() {
        guard captionStack.isHidden else {
            return
        }
        inlineDateAndStateView.isHidden = true
        captionStack.isHidden = false
        NSLayoutConstraint.deactivate([contentStackViewNoCaptionBottomConstraint])
        NSLayoutConstraint.activate([contentStackViewCaptionBottomConstraint])
    }
    
    private func hideCaptionAndDateAndState() {
        guard !captionStack.isHidden else {
            return
        }
        inlineDateAndStateView.isHidden = false
        captionStack.isHidden = true
        NSLayoutConstraint.deactivate([contentStackViewCaptionBottomConstraint])
        NSLayoutConstraint.activate([contentStackViewNoCaptionBottomConstraint])
    }
}

// MARK: - Reusable

extension ChatViewVoiceMessageTableViewCell: Reusable { }

// MARK: - MessageVoiceMessageWaveformViewDelegate

extension ChatViewVoiceMessageTableViewCell: MessageVoiceMessageWaveformViewDelegate {
    func updateProgress(to progress: CGFloat) {
        guard let voiceMessage = voiceMessageAndNeighbors?.message else {
            return
        }
        voiceMessageCellDelegate?.updateProgress(for: voiceMessage, to: progress)
    }
}

// MARK: - MessageTextViewDelegate

extension ChatViewVoiceMessageTableViewCell: MessageTextViewDelegate {
    func showContact(identity: String) {
        chatViewTableViewCellDelegate?.show(identity: identity)
    }
    
    func didSelectText(in textView: MessageTextView?) {
        chatViewTableViewCellDelegate?.didSelectText(in: textView)
    }
}

// MARK: - Playback State Handling

extension ChatViewVoiceMessageTableViewCell {
    func stateButtonAction(_ button: ThemedCodeButton?) {
        guard let voiceMessage = voiceMessageAndNeighbors?.message else {
            let msg = "Cannot take any button action without a message"
            assertionFailure(msg)
            DDLogError(msg)
            return
        }
        
        switch voiceMessage.blobDisplayState {
        case .processed, .pending, .uploading, .uploaded, .sendingError:
            if !isPlaying {
                startPlayback()
            }
            else {
                pausePlayback()
            }
            
            if let voiceMessageButton = button as? MessageVoiceMessageStateButton {
                voiceMessageButton.isPlaying = isPlaying
            }
            
        case .downloading:
            DDLogVerbose("Cancel sync for message with id: \(voiceMessage.objectID)")
            Task {
                await BlobManager.shared.cancelBlobsSync(for: voiceMessage.objectID)
            }
            
        case .remote:
            DDLogVerbose("Start sync for message with id: \(voiceMessage.objectID)")
            Task {
                let result = await BlobManager.shared.syncBlobs(for: voiceMessage.objectID)
                if result == .downloaded {
                    waveformView.render(voiceMessage)
                }
            }

        case .dataDeleted, .fileNotFound:
            return
        }
    }
    
    private func pausePlayback() {
        guard let voiceMessage = voiceMessageAndNeighbors?.message else {
            return
        }
        
        voiceMessageCellDelegate?.pausePlaying()
        
        isPlaying = false
        
        guard let voiceMessageCellDelegate else {
            return
        }
        
        let progress = voiceMessageCellDelegate.getProgress(for: voiceMessage)
        waveformView.updateProgressWaveform(progress)
    }
    
    private func startPlayback() {
        guard let voiceMessageAndNeighbors else {
            DDLogWarn("Could not start playback because voice message was nil")
            return
        }
        
        guard let url = voiceMessageAndNeighbors.message.temporaryBlobDataURL() else {
            DDLogError("Could not get temporary URL for audio message")
            return
        }
        
        let rate = UserSettings.shared().threemaAudioMessagePlaySpeedCurrentValue()
        voiceMessageCellDelegate?.startPlaying(
            message: voiceMessageAndNeighbors.message,
            url: url,
            rate: rate,
            progressCallback: handleProgressCallback,
            pauseCallback: handlePauseCallback,
            finishedCallback: handleFinishedCallback
        )
            
        isPlaying = true
        
        if let voiceMessage = voiceMessageAndNeighbors.message as? FileMessageEntity,
           !voiceMessage.isOwnMessage,
           voiceMessage.consumed == nil {
            // Set the consumed date for the voice message
            let em = BusinessInjector.ui.entityManager
            em.performAndWaitSave {
                if let vm = em.entityFetcher.getManagedObject(by: voiceMessage.objectID) as? FileMessageEntity {
                    vm.consumed = Date()
                }
            }
            micIconOrPlaybackSpeedButton.isConsumed = true
        }
        
        if !isFocused {
            UIAccessibility.post(notification: .layoutChanged, argument: self)
        }
    }
}

// MARK: - Playback Adapter

extension ChatViewVoiceMessageTableViewCell {
    func handleProgressCallback(currentTime: TimeInterval, progress: CGFloat) {
        waveformView.updateProgressWaveform(progress)
        if showsRemaining, let interval = voiceMessageAndNeighbors?.message.durationTimeInterval {
            let timeshown = currentTime - interval
            fileSizeLabel.text = DateFormatter.maybeNegativeTimeFormatted(Int(timeshown))
        }
        else {
            fileSizeLabel.text = DateFormatter.timeFormatted(Int(currentTime))
        }
    }
    
    func handleFinishedCallback(cancelled: Bool) {
        if !cancelled {
            waveformView.updateProgressWaveform(1.0)
            updateMessageMetadataFileSizeLabel(voiceMessage: voiceMessageAndNeighbors?.message)
        }
        else if let voiceMessage = voiceMessageAndNeighbors?.message,
                let progress = voiceMessageCellDelegate?.getProgress(for: voiceMessage) {
            waveformView.updateProgressWaveform(progress)
        }
        else {
            waveformView.updateProgressWaveform(0.0)
        }
        
        isPlaying = false
        
        // Only play next message if our playback wasn't cancelled
        guard !cancelled else {
            return
        }
        
        if let currentMessage = voiceMessageAndNeighbors?.message,
           let nextMessage = voiceMessageAndNeighbors?
           .neighbors.nextMessage,
           let nextFileMessageProvider = nextMessage as? FileMessageProvider {
            if case .voice = nextFileMessageProvider.fileMessageType {
                if !currentMessage.isOwnMessage,
                   !nextMessage.isOwnMessage {
                    // It needs to be in the predefined interval
                    guard abs(
                        nextMessage.sectionDate.timeIntervalSinceReferenceDate - currentMessage.sectionDate
                            .timeIntervalSinceReferenceDate
                    )
                        < ChatViewConfiguration.VoiceMessage.NeighborPlayback
                        .maxDurationForNeighborAutomaticPlaybackInSeconds else {
                        return
                    }
                    
                    chatViewTableViewCellDelegate?.playNextMessageIfPossible(from: currentMessage.objectID)
                }
            }
        }
    }
    
    func handlePauseCallback() {
        isPlaying = false
    }
}

// MARK: - ChatViewMessageActions

extension ChatViewVoiceMessageTableViewCell: ChatViewMessageActions {
    
    func messageActionsSections() -> [ChatViewMessageActionsProvider.MessageActionsSection]? {
        
        guard let message = voiceMessageAndNeighbors?.message else {
            return nil
        }

        typealias Provider = ChatViewMessageActionsProvider
            
        // MessageMarkers
        let markStarHandler = { (message: BaseMessage) in
            self.chatViewTableViewCellDelegate?.toggleMessageMarkerStar(message: message)
        }
        
        // Retry and cancel
        let retryAndCancelHandler = { [weak self] in
            guard let self else {
                return
            }
            
            chatViewTableViewCellDelegate?.retryOrCancelSendingMessage(withID: message.objectID, from: containerView)
        }
        
        // Download
        let downloadHandler: Provider.DefaultHandler = {
            Task {
                await BlobManager.shared.syncBlobs(for: message.objectID)
            }
        }
        
        // Quote
        let quoteHandler = {
            guard let chatViewTableViewCellDelegate = self.chatViewTableViewCellDelegate else {
                DDLogError("[CV CxtMenu] Could not show quote view because the delegate was nil.")
                return
            }
            
            guard let message = message as? QuoteMessage else {
                DDLogError("[CV CxtMenu] Could not show quote view because the message is not a quote message.")
                return
            }
            
            chatViewTableViewCellDelegate.showQuoteView(message: message)
        }
        
        // Copy
        // In the new chat view we always copy the data, regardless if it has a caption because the text can be selected
        // itself.
        let copyHandler = {
            guard let data = message.blobData, let uti = message.blobUTTypeIdentifier else {
                NotificationPresenterWrapper.shared.present(type: .copyError)
                return
            }
            
            UIPasteboard.general.setData(data, forPasteboardType: uti)
            NotificationPresenterWrapper.shared.present(type: .copySuccess)
        }
        
        // Share
        let shareItems = [MessageActivityItem(for: message)]
        
        // Speak
        let speakText = message.fileMessageType.localizedDescription
        
        // Details
        let detailsHandler: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.showDetails(for: message.objectID)
        }
        
        // Select
        let selectHandler: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.startMultiselect(with: message.objectID)
        }
        
        // Delete
        
        let willDelete: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.willDeleteMessage(with: message.objectID)
        }
        
        let didDelete: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.didDeleteMessages()
        }
        
        // Build menu
        return Provider.defaultActions(
            message: message,
            activityViewAnchor: containerView,
            popOverSource: chatBubbleContentView,
            markStarHandler: markStarHandler,
            retryAndCancelHandler: retryAndCancelHandler,
            downloadHandler: downloadHandler,
            quoteHandler: quoteHandler,
            copyHandler: copyHandler,
            shareItems: shareItems,
            speakText: speakText,
            detailsHandler: detailsHandler,
            selectHandler: selectHandler,
            willDelete: willDelete,
            didDelete: didDelete
        )
    }
    
    // MARK: - Accessibility
    
    // Do not read accessibility labels if voice message is playing
    override public var accessibilityLabel: String? {
        get {
            if isPlaying {
                // VoiceOver falls back to traits calling a playing message just "Button" without this
                return #localize("pause")
            }
            
            return super.accessibilityLabel
        }
        
        set {
            // No-op
        }
    }
    
    override var accessibilityValue: String? {
        get {
            if isPlaying {
                return nil
            }
            return super.accessibilityValue
        }
        
        set {
            // No-op
        }
    }
    
    override public var accessibilityHint: String? {
        get {
            if isPlaying {
                return nil
            }
            return super.accessibilityHint
        }
        
        set {
            // No-op
        }
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            stateButtonAction(nil)
        }
    }
    
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            let builtActions = buildAccessibilityCustomActions(reactionsManager: reactionsManager) ??
                [UIAccessibilityCustomAction]()
            let customActionArray = [
                UIAccessibilityCustomAction(
                    name: BundleUtil
                        .localizedString(forKey: "accessibility_voiceMessage_forward_hint")
                ) { _ in
                    if let voiceMessage = self.voiceMessageAndNeighbors?.message {
                        self.waveformView.delegate?.currentTimeForward(for: voiceMessage)
                        return true
                    }
                    return false
                },
                UIAccessibilityCustomAction(
                    name: BundleUtil
                        .localizedString(forKey: "accessibility_voiceMessage_rewind_hint")
                ) { _ in
                    if let voiceMessage = self.voiceMessageAndNeighbors?.message {
                        self.waveformView.delegate?.currentTimeRewind(for: voiceMessage)
                        return true
                    }
                    return false
                },
                UIAccessibilityCustomAction(
                    name: BundleUtil
                        .localizedString(forKey: "accessibility_voiceMessage_speed_hint")
                ) { _ in
                    let newSpeedSetting = UserSettings.shared().threemaAudioMessagePlaySpeedSwitchToNextValue()
                    UIAccessibility.post(
                        notification: UIAccessibility.Notification.announcement,
                        argument: "\(newSpeedSetting)"
                    )
                    self.voiceMessageCellDelegate?.updatePlaybackSpeed(newSpeedSetting)
                    return true
                },
            ]
                
            return customActionArray + builtActions
        }
        set {
            // No-op
        }
    }
}
