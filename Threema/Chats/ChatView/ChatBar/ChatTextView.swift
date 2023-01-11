//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

final class ChatTextView: RTLAligningTextView {
    
    // MARK: - Public properties
    
    override public var attributedText: NSAttributedString! {
        didSet {
            if !isDummy {
                resizeTextView()
                updatePlaceholder()
            }
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
    
    private let draftText: String?
    private var conversationIdentifier: String?
    
    private let markupParser = MarkupParser()
    private(set) var notParsedText = NSAttributedString()
    private var textChangeQueue = [TextChangeItem]()
    
    private lazy var mentionsHelper = MentionsHelper()
    
    private var returnToSend = UserSettings.shared().returnToSend
    
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
        let formattedString = dummyTextView.formattedString(
            range: NSMakeRange(0, 0),
            oldParsedText: NSMutableAttributedString(string: ""),
            text: "3ma",
            textView: dummyTextView
        )
        
        dummyTextView.attributedText = formattedString.attributedString
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
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        self.draftText = nil
        
        super.init(frame: frame, textContainer: textContainer)
        
        configureTextView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.draftText = nil
        
        super.init(coder: aDecoder)
        
        configureTextView()
    }
    
    init(draftText: String? = nil, conversationIdentifier: String? = nil) {
        self.draftText = draftText
        self.conversationIdentifier = conversationIdentifier
        super.init(frame: .zero, textContainer: nil)
        
        configureTextView()
    }
    
    private init(asDummy: Bool) {
        self.isDummy = asDummy
        self.draftText = nil
        
        super.init(frame: .zero, textContainer: nil)
        
        configureTextView()
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: - Configuration
    
    private func configureTextView() {
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
            
        // Load draft
        if let draftText = draftText {
            let range = NSMakeRange(0, 0)
            
            let formattedString = formattedString(
                range: range,
                oldParsedText: NSMutableAttributedString(string: ""),
                text: draftText,
                textView: self
            )
            
            attributedText = formattedString.attributedString
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
        updateTextAlignment()
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
    
    func updateSettings() {
        returnToSend = UserSettings.shared().returnToSend
    }
    
    func updateColors() {
        backgroundColor = Colors.chatBarInput
        layer.borderColor = Colors.hairLine.cgColor
        
        placeholderLabel.textColor = Colors.textPlaceholder
        
        let formattedString = formattedString(
            range: NSMakeRange(0, 0),
            oldParsedText: NSMutableAttributedString(string: ""),
            text: attributedText.string,
            textView: self
        )
        
        attributedText = formattedString.attributedString
    }
    
    private func updatePlaceholder() {
        if attributedText.string.isEmpty {
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
    
    @objc func updateTextAlignment() {
        if let inputModeLocale = textInputMode?.primaryLanguage {
            if NSLocale.characterDirection(forLanguage: inputModeLocale) == .rightToLeft {
                textAlignment = .right
            }
            else {
                textAlignment = .left
            }
        }
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
            selector: #selector(updateTextAlignment),
            name: UITextInputMode.currentInputModeDidChangeNotification,
            object: nil
        )
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notifications
    
    @objc private func preferredContentSizeCategoryDidChange() {
        let range = NSMakeRange(0, 0)
        
        let formattedString = formattedString(
            range: range,
            oldParsedText: NSMutableAttributedString(string: ""),
            text: attributedText.string,
            textView: self
        )
        
        attributedText = formattedString.attributedString
        
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
            textViewDidChange(self)
        }
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
        attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Stops editing, removes the current text from the text view and replaces it with an empty string.
    /// - Returns: If the current text is empty it returns nil otherwise it returns the text
    func removeCurrentText() -> String? {
        let parsedMentions = markupParser.parseMentionNamesToMarkup(parsed: attributedText)
        let text = parsedMentions.string
        attributedText = NSAttributedString(string: "")
        
        guard chatTextViewDelegate != nil else {
            let message = "chatTextViewDelegate should not be nil"
            DDLogError(message)
            assertionFailure(message)
            return nil
        }
        
        isEditing = false
        
        if text != "" {
            return text
        }
        return nil
    }
    
    /// This method processes the changes from shouldChangeTextIn and formats the text
    /// - Parameters:
    ///   - range: The range of the changes as defined in shouldChangeTextIn
    ///   - oldParsedText: The parsed text that was displayed in the UITextView before the current changes were applied
    ///   - text: The text that should be entered in range. As defined in shouldChangeTextIn.
    ///   - textView: The textView that has the current changes
    /// - Returns: A tuple of the newly formatted attributedString and the UITextRange describing the current cursor position
    func formattedString(
        range: NSRange,
        oldParsedText: NSMutableAttributedString,
        text: String,
        textView: UITextView
    ) -> (attributedString: NSAttributedString, textRange: UITextRange?) {
        let currentPosition = textView.beginningOfDocument
        
        let currentReplacementRange = currentReplacementRange(range: range, oldParsedText: oldParsedText)
        
        let replacementText = NSAttributedString(string: text, attributes: nil)
        oldParsedText.replaceCharacters(in: currentReplacementRange, with: replacementText)
        
        notParsedText = markupParser.parseMentionNamesToMarkup(parsed: oldParsedText)
        
        var attributedString = NSAttributedString(
            string: notParsedText.string,
            attributes: [
                NSAttributedString.Key.foregroundColor: Colors.text,
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: Config.textStyle),
            ]
        )
        
        attributedString = markupParser.markify(
            attributedString: attributedString,
            font: UIFont.preferredFont(forTextStyle: Config.textStyle),
            parseMention: true
        ) as! NSMutableAttributedString
        
        let diff = calcPositionOffsetDiff(
            attributedString: attributedString,
            currentReplacementRange: currentReplacementRange
        )
        var textRange: UITextRange?
        if let cursorLocation = position(
            from: currentPosition,
            offset: currentReplacementRange.location + text.utf16.count + diff
        ) {
            textRange = self.textRange(from: cursorLocation, to: cursorLocation)
        }
        
        handleMentions(with: currentReplacementRange, replacementText: text)
        
        return (attributedString, textRange)
    }
    
    /// Should be called to reformat the currently editing mention
    /// - Parameter identity: the mentioned identity
    func mentionsTableViewHasSelected(identity: String) {
        let fullText = attributedText.string as NSString
        
        let replaceRange = mentionsHelper.getReplacementRange(fullText: fullText)
        let replaceText = mentionsHelper.getReplacementText(identity: identity)
        
        mentionsHelper.resetMentions()
        _ = textView(self, shouldChangeTextIn: replaceRange, replacementText: replaceText)
        textViewDidChange(self)
    }
    
    // MARK: - Private Functions
    
    private func currentReplacementRange(range: NSRange, oldParsedText: NSAttributedString) -> NSRange {
        
        guard range.location < oldParsedText.length else {
            return range
        }
        
        var currentReplacementRange = range
        var foundTokenRange = NSRange()
        let searchToken = NSAttributedString.Key.contact
        
        if range.length == 0,
           oldParsedText.attribute(searchToken, at: range.location, effectiveRange: &foundTokenRange) != nil,
           range.location != foundTokenRange.location {
            currentReplacementRange = NSUnionRange(currentReplacementRange, foundTokenRange)
        }
        else {
            // search the range for any instances of the desired text attribute
            oldParsedText.enumerateAttribute(
                searchToken,
                in: range,
                options: .longestEffectiveRangeNotRequired,
                using: { _, attributedRange, _ in
                    // get the attribute's full range and merge it with the original
                    if oldParsedText.attribute(
                        searchToken,
                        at: attributedRange.location,
                        effectiveRange: &foundTokenRange
                    ) != nil {
                        currentReplacementRange = NSUnionRange(currentReplacementRange, foundTokenRange)
                    }
                }
            )
        }
        
        return currentReplacementRange
    }
    
    private func calcPositionOffsetDiff(attributedString: NSAttributedString, currentReplacementRange: NSRange) -> Int {
        var diff = 0
        attributedString.enumerateAttributes(
            in: NSRange(location: 0, length: attributedString.length)
        ) { attributes, mentionRange, stop in
            if attributes[NSAttributedString.Key.tokenType] as? MarkupParser.TokenType == .mention,
               currentReplacementRange.location >= mentionRange.location,
               currentReplacementRange.location < mentionRange.location + mentionRange.length,
               let contact = attributes[NSAttributedString.Key.contact] as? Contact {
                // add the difference between the mention code and the mention name
                diff = contact.displayName.count + 2 - 11
                stop.pointee = true
            }
        }
        return diff
    }
    
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
    
    override var accessibilityValue: String? {
        get {
            if isEmpty {
                return nil
            }
            else {
                return String.localizedStringWithFormat(
                    BundleUtil.localizedString(forKey: "accessibility_chatbar_value"),
                    text
                )
            }
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
    
    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            .allowsDirectInteraction
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
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            (!isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        else {
            return false
        }
        
        let adjustedRange = getAdjustedRange(from: range, with: textView.markedTextRange, in: textView)

        let oldParsedText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        textChangeQueue.append(textViewKeyboardWorkaroundHandler.nextTextViewChange(
            shouldChangeTextIn: adjustedRange,
            replacementText: text,
            oldText: oldParsedText
        ))
        
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
        
        while !textChangeQueue.isEmpty {
            let (range, oldParsedText, text) = textChangeQueue.removeFirst()
            
            let (attributedString, textRange) = formattedString(
                range: range,
                oldParsedText: oldParsedText,
                text: text,
                textView: textView
            )
            
            attributedText = attributedString
            
            if let textRange = textRange {
                selectedTextRange = textRange
            }
            
            if let delegate = chatTextViewDelegate, let chatTextView = textView as? ChatTextView {
                delegate.chatTextViewDidChange(chatTextView)
            }
            
            if returnToSend, text == "\n", !isEmpty {
                isEditing = false
                chatTextViewDelegate?.sendText()
            }
            
            updatePlaceholder()
        }
        resizeTextView()
        setNeedsDisplay()
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
    
    private func getAdjustedRange(
        from range: NSRange,
        with lastMarkedTextRange: UITextRange?,
        in textView: UITextView
    ) -> NSRange {
        /// If we are in multi stage text input mode we need to make sure that we replace the full text instead of just inserting the newly combined character and leaving the previously provisionally inserted text.
        
        var adjustedRange = range
        
        if let lastMarkedTextRange = lastMarkedTextRange {
            let markedStart = textView.offset(from: textView.beginningOfDocument, to: lastMarkedTextRange.start)
            let markedEnd = textView.offset(from: textView.beginningOfDocument, to: lastMarkedTextRange.end)
            let markedLength = markedEnd - markedStart
            
            if let preferredLanguage = Bundle.main.preferredLocalizations.first,
               NSLocale.characterDirection(forLanguage: preferredLanguage) == .rightToLeft {
                adjustedRange.location = max(markedStart, adjustedRange.location)
            }
            else {
                adjustedRange.location = min(markedStart, adjustedRange.location)
            }
            
            adjustedRange.length = max(markedLength, adjustedRange.length)
        }
        
        return adjustedRange
    }
}
