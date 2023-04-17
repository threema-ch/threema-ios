//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

protocol ChatTextViewDelegate: AnyObject {
    // ChatTextView Changes
    func chatTextViewDidChange(_ textView: ChatTextView)
    
    // Sending text
    func sendText()
    func canStartEditing() -> Bool
    func didEndEditing()
}

final class ChatTextView: UITextView {
    
    // MARK: - Public properties
    
    override var textAlignment: NSTextAlignment {
        didSet {
            // This is to work around an issue where the cursor position would switch back to left (even though we explicitly set it to right) after
            // sending a few messages.
            textViewDidChange(self)
        }
    }
    
    override var typingAttributes: [NSAttributedString.Key: Any] {
        set {
            super.typingAttributes = newValue
        }
        get {
            [
                NSAttributedString.Key.foregroundColor: Colors.text,
                NSAttributedString.Key.font: UIFont
                    .preferredFont(forTextStyle: ChatViewConfiguration.ChatTextView.textStyle),
            ]
        }
    }
    
    override var textInputContextIdentifier: String? {
        conversationIdentifier
    }
    
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
    
    private typealias TextChangeItem = (range: NSRange, fullText: NSMutableAttributedString, newText: String)
    private typealias Config = ChatViewConfiguration.ChatTextView
    
    // MARK: - Private properties
    
    fileprivate var isDummy = false
    
    private let precomposedText: String?
    private var conversationIdentifier: String?
    
    private let markupParser = MarkupParser()
    private(set) var notParsedText = NSAttributedString()
    private var textChangeQueue = [TextChangeItem]()
    
    private lazy var mentionsHelper = MentionsHelper()
        
    private lazy var heightConstraint: NSLayoutConstraint = {
        let heightConstraint = heightAnchor.constraint(equalToConstant: minHeight)
        heightConstraint.isActive = true
        return heightConstraint
    }()
    
    private var minHeight: CGFloat {
        if traitCollection.preferredContentSizeCategory < .large {
            return Config.smallerContentSizeConfigurationCornerRadius * 2
        }
        else {
            return Config.cornerRadius * 2
        }
    }
    
    private var maxHeight: CGFloat {
        minHeight * CGFloat(ChatViewConfiguration.ChatBar.maxNumberOfLines)
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
        label.text = BundleUtil.localizedString(forKey: "chat_text_view_placeholder")
        label.isHidden = false
        label.isUserInteractionEnabled = false
        label.font = UIFont.preferredFont(forTextStyle: Config.textStyle)
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
        return label
    }()
    
    private let textViewKeyboardWorkaroundHandler = TextViewKeyboardWorkaroundHandler()
    
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
        removeObservers()
    }
    
    // MARK: - Configuration
    
    private func configureTextView() {
        let menuItem = UIMenuItem(title: BundleUtil.localizedString(forKey: "scan_qr"), action: #selector(scanQRCode))
        UIMenuController.shared.menuItems = [menuItem]

        font = UIFont.preferredFont(forTextStyle: Config.textStyle)
        adjustsFontForContentSizeCategory = true
        
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
        if let precomposedText = precomposedText {
            customTextStorage?.replaceAndParse(precomposedText)
        }
        
        // Design
        layer.borderWidth = Config.borderWidth
        layer.cornerRadius = Config.cornerRadius
        layer.masksToBounds = true
        
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
        updateColors()
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
    
    /// Resizes the text view according to the minimum size that fits the content while respecting the configured maximum size
    /// - Parameter forceHeightCheck: If true the initial sanity check. This is required to properly scroll drafts that have not yet fully loaded. (There might be a race condition hiding behind this.)
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
        
        // Update to new height and layout all sub and relevant superviews
        if height != heightConstraint.constant {
            heightConstraint.constant = height
            
            UIView.performWithoutAnimation {
                /// Calling layoutIfNeeded while we're not in the view causes temporary constraints to be added to our view
                /// which then need to be broken once the real layout is ready.
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
    
    func updateColors() {
        backgroundColor = Colors.chatBarInput
        layer.borderColor = Colors.hairLine.cgColor
        
        placeholderLabel.textColor = Colors.textPlaceholder
        
        // This reformats the text using the new colors
        customTextStorage?.reformatText()
    }
    
    private func updatePlaceholder() {
        if text.isEmpty {
            placeholderLabel.isHidden = false
        }
        else {
            placeholderLabel.isHidden = true
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Only configure on first layout pass that matches all the requirements
        configureInsetsIfNeeded()
        resizeTextView()
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
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            customTextStorage?.reformatText()
        }
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
    
    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                title: BundleUtil.localizedString(forKey: "hardware_keyboard_send_on_enter_discoverability_title"),
                action: #selector(sendOnHWKReturn),
                input: "\r"
            ),
        ]
    }
    
    // MARK: Overrides
    
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
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Stops editing, removes the current text from the text view and replaces it with an empty string.
    /// - Returns: If the current text is empty it returns nil otherwise it returns the text
    func removeCurrentText() -> String? {
        defer {
            updatePlaceholder()
            resizeTextView()
            setNeedsDisplay()
            
            // Workaround
            /// When removing the text we also need to reset the selected range to properly update predictive typing
            selectedRange = NSRange(location: 0, length: 0)
        }
        
        let currentText = customTextStorage?.removeCurrentText()
        
        guard chatTextViewDelegate != nil else {
            let message = "chatTextViewDelegate should not be nil"
            DDLogError(message)
            assertionFailure(message)
            return nil
        }
        
        isEditing = false
        
        if currentText != "" {
            return currentText
        }
        return nil
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
    
    @objc private func scanQRCode() {
        let qrController = QRScannerViewController()
        
        qrController.delegate = self
        qrController.title = BundleUtil.localizedString(forKey: "scan_qr")
        qrController.navigationItem.scrollEdgeAppearance = Colors.defaultNavigationBarAppearance()

        let nav = PortraitNavigationController(rootViewController: qrController)

        nav.modalTransitionStyle = .crossDissolve
        window?.rootViewController?.present(nav, animated: true)
    }
}

// MARK: - Accessibility

extension ChatTextView {

    override var accessibilityLabel: String? {
        get {
            BundleUtil.localizedString(forKey: "accessibility_chatbar_label")
        }
        set {
            // Do nothing
        }
    }
    
    override var accessibilityHint: String? {
        get {
            BundleUtil.localizedString(forKey: "accessibility_chatbar_hint")
        }
        set {
            // Do nothing
        }
    }
}

// MARK: - UITextViewDelegate

extension ChatTextView: UITextViewDelegate {
    internal func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        chatTextViewDelegate?.canStartEditing() ?? false
    }
    
    /// This implements shouldChangeTextIn from UITextViewDelegate
    ///
    /// It was originally intended to live format the text and return false. However due to an issue with auto capitalization
    /// when programmatically changing the text in here, the changes are added to a queue and processed in order in textViewDidChange.
    /// When programmatically changing the text with auto capitalization turned on arbitrary letters would get auto capitalized even when not at the beginning of a sentence.
    /// This behavior seems to have changed two years ago and none of the fixes in https://stackoverflow.com/q/58425591 work for us.
    /// Additionally we only allow inserting characters that can actually be sent. E.g. leading newlines or spaces are not allowed.
    /// - Parameters:
    ///   - textView: Text view that called delegate
    ///   - range: Range of change
    ///   - text: New text for this range
    /// - Returns: Must always return true otherwise the text needs to be assigned to the textView manually
    internal func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard range.length != 0 ||
            (
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    (!isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
        else {
            return false
        }
        
        handleMentions(with: range, replacementText: text)

        return true
    }
    
    /// Implements textViewDidChange from UITextViewDelegate
    ///
    /// See the documentation for shouldChangeTextIn for more information about why we have this queue and are formatting the text in here.
    /// For each append of the queue there is one call to textViewDidChange. So the while-loop is not strictly necessary.
    /// Please do all expensive formatting changes in formattedString and performance test them with ChatTextViewPerformanceTest. Tests are not executed automatically. They need to be enabled manually.
    /// - Parameter textView: Text view that called delegate
    internal func textViewDidChange(_ textView: UITextView) {
        /// Marked text is provisionally inserted text that requires user confirmation. It occurs in multistage text input, e.g. when entering ¨ and u to get a combined ü
        /// We keep track of provisionally inserted text and combine the marked and shouldChangeTextIn ranges in func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool above.
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

            if let textRange = textRange {
                selectedTextRange = textRange
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
    
    internal func textViewDidEndEditing(_ textView: UITextView) {
        if isEditing {
            isEditing = false
        }
        
        updatePlaceholder()
        
        isEditing = false
        
        resignFirstResponder()
    }
    
    // MARK: Private Helper Functions
    
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
}

// MARK: - QRScannerViewControllerDelegate

extension ChatTextView: QRScannerViewControllerDelegate {
    func qrScannerViewController(_ controller: QRScannerViewController, didScanResult result: String?) {
        if let result = result {
            insertText(result)
        }
        controller.dismiss(animated: true)
    }
    
    func qrScannerViewController(
        _ controller: QRScannerViewController,
        didCancelAndWillDismissItself willDismissItself: Bool
    ) {
        if !willDismissItself {
            controller.dismiss(animated: true)
        }
    }
}
