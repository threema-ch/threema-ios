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

protocol ChatTextViewDelegate: AnyObject {
    func chatTextViewDidChange(_ textView: ChatTextView)
    func showContact(identity: String)
    
    // Sending text
    func sendText()
    func canStartEditing() -> Bool
    func didEndEditing()
    func checkIfPastedStringIsMedia() -> Bool
    @available(iOS 18.0, *)
    func processAndSendGlyph(_ glyph: NSAdaptiveImageGlyph)
}

final class ChatTextView: UITextView {
    
    // MARK: - Overrides UITextView

    override var textAlignment: NSTextAlignment {
        didSet {
            // This is to work around an issue where the cursor position would switch back to left (even though we
            // explicitly set it to right) after sending a few messages.
            guard oldValue != textAlignment else {
                return
            }
            
            textViewDidChange(self)
        }
    }
    
    override var typingAttributes: [NSAttributedString.Key: Any] {
        set {
            super.typingAttributes = newValue
        }
        get {
            [
                NSAttributedString.Key.foregroundColor: UIColor.label,
                NSAttributedString.Key.font: UIFont
                    .preferredFont(forTextStyle: ChatViewConfiguration.ChatTextView.textStyle),
            ]
        }
    }

    override func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {
        switch writingDirection {
        case .natural:
            textAlignment = .natural
        case .leftToRight:
            textAlignment = .left
        case .rightToLeft:
            textAlignment = .right
        @unknown default:
            DDLogWarn("Unknown default case \(writingDirection)")
            textAlignment = .natural
        }

        textViewDidChange(self)

        configureInsetsIfNeeded()
    }

    // MARK: - Overrides UIResponder

    override var textInputContextIdentifier: String? {
        conversationIdentifier
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard action == #selector(paste(_:)) else {
            return super.canPerformAction(action, withSender: sender)
        }
        
        let hasTextOrURL = UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs
        let hasImages = UIPasteboard.general.hasImages
        
        if hasImages || !hasTextOrURL {
            return true
        }
        else {
            return super.canPerformAction(action, withSender: sender)
        }
    }

    override func paste(_ sender: Any?) {
        let hasTextOrURL = UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs
        let hasImages = UIPasteboard.general.hasImages
        
        if hasImages || !hasTextOrURL {
            if UIPasteboard.general.numberOfItems > 0 {
                handlePasteItem()
            }
        }
        else {
            super.paste(sender)
        }
    }

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                title: #localize("hardware_keyboard_send_on_enter_discoverability_title"),
                action: #selector(sendOnHWKReturn),
                input: "\r"
            ),
        ]
    }

    // MARK: - Overrides UIView

    override func layoutSubviews() {
        super.layoutSubviews()

        // Only configure on first layout pass that matches all the requirements
        configureInsetsIfNeeded()
        resizeTextView()
    }

    // MARK: - Public properties

    /// Returns the amount by which chat view inset from the leading edge.
    ///
    /// This is currently only used to align the quote view.
    var textBeginningInset: CGFloat {
        frame.minX
    }
    
    /// Keeping track of whether `didBeginEditing` and `didEndEditing` have been called.
    /// True when `didBeginEditing` was called but `didEndEditing` was not yet called.
    /// False otherwise
    var isEditing = false
    
    // MARK: - Delegates
    
    weak var chatTextViewDelegate: ChatTextViewDelegate?
    weak var mentionsTableViewDelegate: MentionsTableViewDelegate?
    
    // MARK: - Private type
    
    private typealias Config = ChatViewConfiguration.ChatTextView
    
    // MARK: - Private properties
    
    fileprivate var isDummy = false
    
    private let precomposedText: String?
    private var conversationIdentifier: String?
    private var menuInteraction: UIEditMenuInteraction?

    private let markupParser = MarkupParser()

    private lazy var mentionsHelper = MentionsHelper()
        
    private lazy var heightConstraint: NSLayoutConstraint = {
        let heightConstraint = heightAnchor.constraint(equalToConstant: minHeight)
        heightConstraint.isActive = true
        return heightConstraint
    }()
    
    private var minHeight: CGFloat {
        if traitCollection.preferredContentSizeCategory < .large {
            Config.smallerContentSizeConfigurationCornerRadius * 2
        }
        else {
            Config.cornerRadius * 2
        }
    }
    
    private var maxHeight: CGFloat {
        guard UIDevice.current.orientation.isLandscape, UIDevice.current.userInterfaceIdiom != .pad else {
            if UIScreen.main.bounds.height <= 568 {
                return minHeight * CGFloat(ChatViewConfiguration.ChatBar.maxNumberOfLinesPortraitSmallScreen)
            }
            
            return minHeight * CGFloat(ChatViewConfiguration.ChatBar.maxNumberOfLinesPortrait)
        }
        
        guard UIScreen.main.bounds.height > 320 else {
            return minHeight * CGFloat(ChatViewConfiguration.ChatBar.maxNumberOfLinesLandscapeSmallScreen)
        }
        
        return minHeight * CGFloat(ChatViewConfiguration.ChatBar.maxNumberOfLinesLandscape)
    }
    
    private var prevSingleLineHeight: CGFloat = 0.0
    
    private lazy var dummyTextView: ChatTextView = {
        let dummyTextView = ChatTextView(asDummy: true)
        
        dummyTextView.customTextStorage?.replaceAndParse("3ma")
        dummyTextView.contentMode = .redraw

        dummyTextView.sizeToFit()
        
        return dummyTextView
    }()
    
    private lazy var singleLineHeight: CGFloat = dummyTextView.textContainer.size.height
    
    // MARK: Views & layout
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = #localize("chat_text_view_placeholder")
        label.isHidden = false
        label.isUserInteractionEnabled = false
        label.font = UIFont.preferredFont(forTextStyle: Config.textStyle)
        label.textColor = .placeholderText
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
        return label
    }()
        
    private var customTextStorage: MarkupParsingTextStorage?
    
    // MARK: - Lifecycle
    
    init(precomposedText: String? = nil, conversationIdentifier: String? = nil) {
        self.precomposedText = precomposedText
        self.conversationIdentifier = conversationIdentifier
        
        let container = NSTextContainer(size: .zero)
        container.widthTracksTextView = true
        
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        
        let textStorage = MarkupParsingTextStorage()
        textStorage.addLayoutManager(layoutManager)
        
        super.init(frame: .zero, textContainer: container)
        
        textStorage.markupParsingTextStorageDelegate = self
        
        self.customTextStorage = textStorage
        
        configureTextView()
    }
    
    private convenience init(asDummy: Bool) {
        self.init(precomposedText: nil)
        
        self.isDummy = asDummy
        
        configureTextView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        DDLogVerbose("\(#function)")
        removeObservers()
    }

    private func configureTextView() {
        font = UIFont.preferredFont(forTextStyle: Config.textStyle)
        backgroundColor = .secondarySystemGroupedBackground
        adjustsFontForContentSizeCategory = true
        
        if #available(iOS 18.0, *) {
            // To address the malfunction with the deactivate sticker switch, situated within the iOS settings
            supportsAdaptiveImageGlyph = false
        }
        
        textContainer.lineFragmentPadding = 0
        
        isScrollEnabled = false
        scrollIndicatorInsets = UIEdgeInsets(
            top: Config.cornerRadius,
            left: 0,
            bottom: Config.cornerRadius,
            right: 0
        )
        
        delegate = self
            
        // Set precomposed text
        if let precomposedText {
            customTextStorage?.replaceAndParse(precomposedText)
            sizeToFit()
        }
        
        // Design
        layer.borderWidth = Config.borderWidth
        layer.cornerRadius = Config.cornerRadius
        layer.masksToBounds = true
        layer.borderColor = UIColor.separator.cgColor
        
        // Set to default insets
        // They might be updated in `configureInsetsIfNeeded()`
        textContainerInset = UIEdgeInsets(
            top: Config.minTopAndBottomInset,
            left: Config.leadingAndTrailingInset,
            bottom: Config.minTopAndBottomInset,
            right: Config.leadingAndTrailingInset
        )
        
        configureLayout()
        
        addObservers()
        
        updatePlaceholder()
        resizeTextView()
    }
    
    private func configureLayout() {
        addSubview(placeholderLabel)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // We assume the first line of text input is always correctly centered by its insets
            placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Config.leadingAndTrailingInset
            ),
            placeholderLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -Config.leadingAndTrailingInset
            ),
        ])

        resizeTextView(forceHeightCheck: !isDummy)
    }
    
    /// Resizes the text view according to the minimum size that fits the content while respecting the configured
    /// maximum size
    /// - Parameter forceHeightCheck: If true the initial sanity check. This is required to properly scroll drafts that
    ///                               have not yet fully loaded. (There might be a race condition hiding behind this.)
    private func resizeTextView(forceHeightCheck: Bool = false) {
        guard forceHeightCheck || prevSingleLineHeight != 0.0 || numberOfLines > 1 else {
            setNeedsLayout()
            return
        }
        
        let maxSize = CGSize(width: bounds.size.width, height: .greatestFiniteMagnitude)
        var height = max(sizeThatFits(maxSize).height, minHeight)
        
        isScrollEnabled = height > maxHeight
        
        // Constrain maximum height
        height = min(height, maxHeight)
        
        contentSize.height = ceil(sizeThatFits(frame.size).height)
        
        // Update to new height and layout all sub and relevant superviews
        if height != heightConstraint.constant {
            heightConstraint.constant = height
            
            UIView.performWithoutAnimation {
                /// Calling layoutIfNeeded while we're not in the view causes temporary constraints to be added to our
                /// view which then need to be broken once the real layout is ready.
                /// We just won't animate as long as we're not added to the view hierarchy.
                guard self.window != nil else {
                    return
                }
                // TODO: IOS-2562
                // Otherwise ChatViewController might miss our new height and animate it at an unfortunate time
                superview?.setNeedsLayout()
                superview?.superview?.setNeedsLayout()
                superview?.superview?.superview?.setNeedsLayout()
                setNeedsLayout()
                
                superview?.layoutIfNeeded()
                superview?.superview?.layoutIfNeeded()
                superview?.superview?.superview?.layoutIfNeeded()
                layoutIfNeeded()
            }
        }
    }
    
    // MARK: - Update
        
    private func updatePlaceholder() {
        if text.isEmpty {
            placeholderLabel.isHidden = false
        }
        else {
            placeholderLabel.isHidden = true
        }
    }

    private func configureInsetsIfNeeded() {
        guard !isDummy else {
            return
        }
        
        guard prevSingleLineHeight == 0.0 else {
            return
        }
        
        prevSingleLineHeight = singleLineHeight
        let singleLineMinHeight = Config.cornerRadius * 2
        let optimalInsets = (singleLineMinHeight - prevSingleLineHeight) / CGFloat(2)
        
        let newTopAndBottomInsets = max(optimalInsets, Config.minTopAndBottomInset)
        
        // Only update insets if they actually changed
        guard newTopAndBottomInsets != textContainerInset.top else {
            return
        }
        
        textContainerInset = UIEdgeInsets(
            top: newTopAndBottomInsets,
            left: Config.leadingAndTrailingInset,
            bottom: newTopAndBottomInsets,
            right: Config.leadingAndTrailingInset
        )
        
        setNeedsDisplay()
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    // MARK: - Observers
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredContentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLayoutForKeyboard),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )

        let traits: [UITrait] = [UITraitUserInterfaceStyle.self, UITraitPreferredContentSizeCategory.self]
        registerForTraitChanges(traits) { [weak self] (_: Self, previous) in
            guard let self else {
                return
            }
            if previous.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
                customTextStorage?.reformatText()
            }
            if previous.userInterfaceStyle != traitCollection.userInterfaceStyle {
                // CGColors don’t auto-update with appearance changes
                layer.borderColor = UIColor.separator.cgColor
                customTextStorage?.reformatText()
            }
        }
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notifications
    
    @objc private func preferredContentSizeCategoryDidChange() {
        // This reformats the text using the new text size
        customTextStorage?.reformatText()
        
        prevSingleLineHeight = 0.0
        configureInsetsIfNeeded()
        resizeTextView()
        setNeedsLayout()
        superview?.setNeedsLayout()
        superview?.superview?.setNeedsLayout()
    }

    @objc func updateLayoutForKeyboard(notification: NSNotification) {
        isEditing = false
        chatTextViewDelegate?.didEndEditing()
    }
    
    @objc private func sendOnHWKReturn() {
        if !isEmpty {
            isEditing = false
            chatTextViewDelegate?.sendText()
            
            // This covers the case where a draft is sent using the HW keyboard
            textViewDidEndEditing(self)
            becomeFirstResponder()
        }
    }

    // MARK: - Get information
    
    /// Approximation of number of lines
    ///
    /// This might be 0 at the beginning even if there is some (multi-line) text.
    var numberOfLines: Int {
        if let fontUnwrapped = font {
            return Int(contentSize.height / fontUnwrapped.lineHeight)
        }
        
        return 0
    }
    
    var isEmpty: Bool {
        ThreemaUtility.trimCharacters(in: text).isEmpty
    }
    
    /// Stops editing, removes the current text from the text view and replaces it with an empty string.
    func removeCurrentText() {
        defer {
            updatePlaceholder()
            resizeTextView()
            setNeedsDisplay()
            
            // Workaround
            /// When removing the text we also need to reset the selected range to properly update predictive typing
            selectedRange = NSRange(location: 0, length: 0)
        }
        
        _ = customTextStorage?.removeCurrentText()
        
        guard chatTextViewDelegate != nil else {
            let message = "chatTextViewDelegate should not be nil"
            DDLogError("\(message)")
            assertionFailure(message)
            return
        }
        
        isEditing = false
    }
    
    /// Stops editing, removes the current text from the text view and replaces it with an empty string.
    /// - Returns: If the current text is empty it returns nil otherwise it returns the text
    func getCurrentText() -> String? {
        guard let customTextStorage else {
            return nil
        }
        
        let parsedMentions = markupParser.parseMentionNamesToMarkup(parsed: customTextStorage.getRawText())
        if parsedMentions.string != "" {
            return parsedMentions.string
        }
        return nil
    }

    /// Insert new or replace message text, will be used for edit message.
    /// - Parameter text: Message text for editing
    func setCurrentText(_ text: String) {
        self.text = text

        updatePlaceholder()
        resizeTextView()
        setNeedsDisplay()

        // Workaround
        /// When removing the text we also need to reset the selected range to properly update predictive typing
        selectedRange = NSRange(location: 0, length: 0)

        // If text field not empty (eg for edit message) set cursor at the end of the text
        if !self.text.isEmpty {
            selectedTextRange = textRange(from: endOfDocument, to: endOfDocument)
        }

        customTextStorage?.reformatText()
    }

    // MARK: - Change text in text view
    
    /// Should be called to reformat the currently editing mention
    /// - Parameter identity: the mentioned identity
    func mentionsTableViewHasSelected(identity: String) {
        let fullText = text as NSString
        
        let replaceRange = mentionsHelper.getReplacementRange(fullText: fullText)
        let replaceText = mentionsHelper.getReplacementText(identity: identity) + " "
        
        mentionsHelper.resetMentions()
        
        let prevLength = textStorage.length
        textStorage.replaceCharacters(in: replaceRange, with: replaceText)
        
        let newLength = textStorage.length
        let diff = newLength - prevLength
        selectedRange = NSRange(location: replaceRange.upperBound + diff, length: 0)
        
        updatePlaceholder()
        resizeTextView()
    }
    
    // MARK: - Handle custom edit menu actions
    
    override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        let canScan = DeviceCapabilitiesManager().supportsRecordingVideo
        let scanAction = UIAction(title: #localize("scan_qr")) { [weak self] _ in
            self?.scanQRCode()
        }
        let customActions: [UIMenuElement] = canScan ? [scanAction] : []
        
        return UIMenu(children: suggestedActions + customActions)
    }
    
    // MARK: - Private Functions
    
    private func handleMentions(with currentReplacementRange: NSRange, replacementText text: String) {
        if let mentionString = mentionsHelper.couldBeMention(text: text, location: currentReplacementRange) {
            let hasMatches = mentionsTableViewDelegate?.hasMatches(for: mentionString) ?? false
            mentionsHelper.lastChangeFoundMatches = hasMatches
            mentionsTableViewDelegate?.shouldHideMentionsTableView(!hasMatches)
        }
        else {
            mentionsTableViewDelegate?.shouldHideMentionsTableView(true)
        }
    }

    private var topViewController: UIViewController {
        AppDelegate.shared().currentTopViewController() ?? .init()
    }

    private func scanQRCode() {
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
            topViewController.dismiss(animated: true) { [weak self] in
                self?.insertText(text)
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
}

// MARK: - Accessibility

extension ChatTextView {

    override var accessibilityLabel: String? {
        get {
            #localize("accessibility_chatbar_label")
        }
        set {
            // Do nothing
        }
    }
    
    override var accessibilityHint: String? {
        get {
            #localize("accessibility_chatbar_hint")
        }
        set {
            // Do nothing
        }
    }
}

// MARK: - UITextViewDelegate

extension ChatTextView: UITextViewDelegate {
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        chatTextViewDelegate?.canStartEditing() ?? false
    }
    
    /// This implements shouldChangeTextIn from UITextViewDelegate
    ///
    /// It was originally intended to live format the text and return false. However due to an issue with auto
    /// capitalization when programmatically changing the text in here, the changes are added to a queue and processed
    /// in order in textViewDidChange. When programmatically changing the text with auto capitalization turned on
    /// arbitrary letters would get auto capitalized even when not at the beginning of a sentence. This behavior seems
    /// to have changed two years ago and none of the fixes in https://stackoverflow.com/q/58425591 work for us.
    ///
    /// Additionally we only allow inserting characters that can actually be sent. E.g. leading newlines or spaces are
    /// not allowed.
    ///
    /// - Parameters:
    ///   - textView: Text view that called delegate
    ///   - range: Range of change
    ///   - text: New text for this range
    /// - Returns: Must always return true otherwise the text needs to be assigned to the textView manually
    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard range.length != 0 ||
            (
                !ThreemaUtility.trimCharacters(in: text).isEmpty ||
                    (!isEmpty && ThreemaUtility.trimCharacters(in: text).isEmpty)
            )
        else {
            return false
        }
        
        handleMentions(with: range, replacementText: text)

        return true
    }
    
    /// Implements textViewDidChange from UITextViewDelegate
    ///
    /// See the documentation for shouldChangeTextIn for more information about why we have this queue and are
    /// formatting the text in here.
    ///
    /// For each append of the queue there is one call to textViewDidChange. So the while-loop is not strictly
    /// necessary.
    ///
    /// Please do all expensive formatting changes in formattedString and performance test them with
    /// ChatTextViewPerformanceTest. Tests are not executed automatically. They need to be enabled manually.
    ///
    /// - Parameter textView: Text view that called delegate
    func textViewDidChange(_ textView: UITextView) {
        /// Marked text is provisionally inserted text that requires user confirmation. It occurs in multistage text
        /// input, e.g. when entering ¨ and u to get a combined ü We keep track of provisionally inserted text and
        /// combine the marked and shouldChangeTextIn ranges in `func textView(_ textView: UITextView,
        /// shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool` above.
        if textView.markedTextRange != nil {
            updatePlaceholder()
            setNeedsDisplay()
            return
        }
        
        if let delegate = chatTextViewDelegate, let chatTextView = textView as? ChatTextView {
            delegate.chatTextViewDidChange(chatTextView)
        }
        
        DDLogVerbose("TextChange \(#function) \(textView.textStorage.string)")
        
        if let customTextStorage, let currentReplacementRange = customTextStorage.lastReplacementRange,
           let lastTextChange = customTextStorage.lastTextChange {
            let diff = calcPositionOffsetDiff(
                attributedString: customTextStorage.getRawText(),
                currentReplacementRange: currentReplacementRange
            )
            if diff > 0 {
                var textRange: UITextRange?
                if let cursorLocation = position(
                    from: textView.beginningOfDocument,
                    offset: currentReplacementRange.location + lastTextChange.utf16.count + diff
                ) {
                    textRange = self.textRange(from: cursorLocation, to: cursorLocation)
                }
                else if let cursorLocation = position(
                    from: textView.beginningOfDocument,
                    offset: customTextStorage.length
                ) {
                    textRange = self.textRange(from: cursorLocation, to: cursorLocation)
                }
                
                if let textRange {
                    selectedTextRange = textRange
                }
            }
        }

        updatePlaceholder()
        resizeTextView()
        setNeedsDisplay()
        
        isEditing = !isEmpty
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if !isEditing {
            isEditing = true
        }
    }

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard
            case let .link(url) = textItem.content,
            IDNASafetyHelper.isLegalURL(url: url, viewController: AppDelegate.shared().currentTopViewController())
        else {
            return nil
        }

        let urlString = url.absoluteString

        if urlString.starts(with: "ThreemaId:") {
            return UIAction(title: defaultAction.title, image: defaultAction.image) { [weak self] _ in
                guard let self else {
                    return
                }

                let threemaID = String(urlString.suffix(8))

                guard let delegate = chatTextViewDelegate else {
                    let msg = "chatTextViewDelegate is unexpectedly nil"
                    assertionFailure(msg)
                    DDLogError("\(msg)")
                    return
                }

                delegate.showContact(identity: threemaID)
            }
        }
        else if url.scheme == "http" || url.scheme == "https", url.host?.lowercased() == "threema.id" {
            return UIAction(title: defaultAction.title, image: defaultAction.image) { _ in
                URLHandler.handleThreemaDotIDURL(url, hideAppChooser: false)
            }
        }
        else {
            return nil
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if isEditing {
            isEditing = false
        }
        
        updatePlaceholder()
        
        isEditing = false
        
        resignFirstResponder()
    }

    // MARK: Helpers

    private func calcPositionOffsetDiff(attributedString: NSAttributedString, currentReplacementRange: NSRange) -> Int {
        var diff = 0
        attributedString.enumerateAttributes(
            in: NSRange(location: 0, length: attributedString.length)
        ) { attributes, mentionRange, stop in
            if attributes[NSAttributedString.Key.tokenType] as? MarkupParser.TokenType == .mention,
               currentReplacementRange.location >= mentionRange.location,
               currentReplacementRange.location < mentionRange.location + mentionRange.length,
               let contact = attributes[NSAttributedString.Key.contact] as? ContactEntity {
                // add the difference between the mention code and the mention name
                diff = contact.displayName.count + 2 - 11
                stop.pointee = true
            }
        }
        return diff
    }

    private func handlePasteItem() {
        _ = chatTextViewDelegate?.checkIfPastedStringIsMedia()
    }
}

// MARK: - MarkupParsingTextStorageDelegate

extension ChatTextView: MarkupParsingTextStorageDelegate {
    @available(iOS 18.0, *)
    func didInsertAdaptiveGlyph(glyph: NSAdaptiveImageGlyph) {
        chatTextViewDelegate?.processAndSendGlyph(glyph)
    }
}
