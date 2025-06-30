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
import ThreemaFramework
import ThreemaMacros
import UIKit

protocol MessageTextViewDelegate: AnyObject {
    var currentSearchText: String? { get }

    func showContact(identity: String)
    func didSelectText(in textView: MessageTextView?)
}

/// Label with correct font for a text message or caption
final class MessageTextView: RTLAligningTextView {
    private struct MessageTextViewRenderState {
        enum RenderState {
            case textUnchanged(SearchTextRenderState)
            case textChanged(SearchTextRenderState)
        }
        
        enum SearchTextRenderState {
            case empty
            case textUnchanged
            case textChanged
        }
        
        var currentText = ""
        var currentSearchText: String?
        
        func renderState(for newText: String, highlighting searchText: String?) -> RenderState {
            let currentSearchTextRenderState: SearchTextRenderState =
                if let searchText {
                    (searchText == currentSearchText) ? .textUnchanged : .textChanged
                }
                else {
                    .empty
                }
            
            guard currentText == newText else {
                DDLogVerbose("Text Changed")
                return .textChanged(currentSearchTextRenderState)
            }
            DDLogVerbose("Text Unchanged")
            return .textUnchanged(currentSearchTextRenderState)
        }
    }
    
    /// Delegate used to handle cell delegates
    private weak var messageTextViewDelegate: MessageTextViewDelegate?
    
    private lazy var markupParser = MarkupParser()
    
    private var currentRenderState = MessageTextViewRenderState()
    
    private var hasHighlightedSearchResult = false
    
    /// Displayed raw text
    ///
    /// When set it will parse the string and automatically set the attributed text
    override public var text: String! {
        get {
            currentRenderState.currentText
        }
        set {
            let currentSearchText = messageTextViewDelegate?.currentSearchText
            
            defer {
                currentRenderState = MessageTextViewRenderState(
                    currentText: newValue,
                    currentSearchText: currentSearchText
                )
            }
            
            switch currentRenderState.renderState(
                for: newValue,
                highlighting: currentSearchText
            ) {
            case let .textUnchanged(searchTextState):
                switch searchTextState {
                case .empty: break //  This is the general case when reconfiguring the parent cell
                case .textChanged:
                    // This only happens when searching
                    //
                    // If the search text has changed we need to do a full markify round because we don't know what
                    // exactly has changed and then highlight the text again.
                    setAttributedText(to: markify(newValue), maybeHighlighting: currentSearchText)
                case .textUnchanged:
                    // This only happens when searching
                    //
                    // Even if both text and search text are unchanged we need to re-markify this text because
                    // of Colors overwriting our previously set colors. See `updateColors` of this class for the other
                    // part of the workaround where we set text to the same value again.
                    setAttributedText(to: attributedText, maybeHighlighting: currentSearchText)
                }
            case .textChanged:
                // This is the general case when setting a new message to the parent cell
                setAttributedText(to: markify(newValue), maybeHighlighting: currentSearchText)
            }
        }
    }
        
    // MARK: - Lifecycle

    init(frame: CGRect, textContainer: NSTextContainer?, messageTextViewDelegate: MessageTextViewDelegate?) {
        self.messageTextViewDelegate = messageTextViewDelegate
        super.init(frame: frame, textContainer: textContainer)
        configureTextView()
    }
    
    required init?(coder: NSCoder, messageTextViewDelegate: MessageTextViewDelegate) {
        self.messageTextViewDelegate = messageTextViewDelegate
        super.init(coder: coder)
        configureTextView()
    }
    
    convenience init(messageTextViewDelegate: MessageTextViewDelegate?) {
        self.init(frame: .zero, textContainer: nil, messageTextViewDelegate: messageTextViewDelegate)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureTextView() {
        font = UIFont.preferredFont(forTextStyle: ChatViewConfiguration.Text.textStyle)
        textColor = .label
        adjustsFontForContentSizeCategory = true
        isScrollEnabled = false
        isEditable = false
        isSelectable = true
        dataDetectorTypes = [.phoneNumber]
        isUserInteractionEnabled = true
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.lineFragmentPadding = 0.0
        delegate = self
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        linkTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.linkColor]
        
        // Needed to detect and ignore long-presses and pans on the view
        for gestureRecognizer in gestureRecognizers ?? [] {
            // To still allow link interactions, we do not override the delegate
            guard !(gestureRecognizer.name?.contains("dragAddingItems") ?? false) else {
                continue
            }
            
            gestureRecognizer.delegate = self
        }
    }
        
    // MARK: - Private Helper Functions
        
    private func setAttributedText(to text: NSAttributedString, maybeHighlighting searchText: String? = nil) {
        if let searchText {
            attributedText = highlight(
                searchText,
                in: NSMutableAttributedString(attributedString: text)
            )
        }
        else {
            attributedText = text
        }
    }
    
    private func highlight(_ searchText: String, in attributedString: NSMutableAttributedString) -> NSAttributedString {
        #if DEBUG
            DDLogVerbose("Start \(#function) for \(Unmanaged.passUnretained(self).toOpaque())")
            let startTime = CACurrentMediaTime()
            defer {
                let endTime = CACurrentMediaTime()
                DDLogVerbose(
                    "End \(#function) for \(Unmanaged.passUnretained(self).toOpaque()) in \(endTime - startTime)"
                )
            }
        #endif
        
        return markupParser.highlightOccurrences(of: searchText, in: attributedString)
    }
    
    private func markify(_ text: String) -> NSAttributedString {
        #if DEBUG
            DDLogVerbose("Start \(#function) for \(Unmanaged.passUnretained(self).toOpaque())")
            let startTime = CACurrentMediaTime()
            defer {
                let endTime = CACurrentMediaTime()
                DDLogVerbose(
                    "End \(#function) for \(Unmanaged.passUnretained(self).toOpaque()) in \(endTime - startTime)"
                )
            }
        #endif
        
        if !UserSettings.shared().disableBigEmojis,
           text.containsOnlyEmoji,
           text.emojis.count <= 3 {
            return NSAttributedString(
                string: text,
                attributes: [
                    NSAttributedString.Key.foregroundColor: UIColor.label,
                    NSAttributedString.Key.font: UIFont
                        .preferredFont(forTextStyle: ChatViewConfiguration.Text.emojiTextStyle),
                ]
            )
        }
        else {
            let attributedString = NSAttributedString(
                string: text,
                attributes: [
                    NSAttributedString.Key.foregroundColor: UIColor.label,
                    NSAttributedString.Key.font: UIFont
                        .preferredFont(forTextStyle: ChatViewConfiguration.Text.textStyle),
                ]
            )
            
            if messageTextViewDelegate != nil {
                return markupParser.markify(
                    attributedString: attributedString,
                    font: UIFont.preferredFont(forTextStyle: ChatViewConfiguration.Text.textStyle),
                    removeMarkups: true
                ) as! NSMutableAttributedString
            }
            else {
                return NSMutableAttributedString(attributedString: attributedString)
            }
        }
    }
    
    func resetTextSelection() {
        selectedTextRange = nil
    }
    
    func accessibilityCustomActions(
        openURLHandler: @escaping (URL) -> Void,
        openDetailsHandler: @escaping (String) -> Void
    ) -> [UIAccessibilityCustomAction]? {

        var customActionsWithRanges = [(range: NSRange, action: UIAccessibilityCustomAction)]()

        // Check for links and phone numbers
        customActionsWithRanges.append(contentsOf: checkForURLs(in: attributedText, openURLHandler: openURLHandler))
       
        // Check for mentions
        customActionsWithRanges
            .append(contentsOf: checkForMentions(in: attributedText, openDetailsHandler: openDetailsHandler))
        
        // Check if we received actions
        guard !customActionsWithRanges.isEmpty else {
            return nil
        }
        
        // Sort by order of occurrence
        let sortedActions = customActionsWithRanges.sorted { $0.range.lowerBound < $1.range.lowerBound }
        
        // Extract actions and return
        return sortedActions.map(\.action)
    }
    
    private func checkForURLs(
        in attributedString: NSAttributedString,
        openURLHandler: @escaping (URL) -> Void
    ) -> [(NSRange, UIAccessibilityCustomAction)] {
       
        var accessibilityCustomActionsURLs = [(NSRange, UIAccessibilityCustomAction)]()
       
        // Are there even results?
        guard let results = checkForCheckingResults(in: attributedText) else {
            return accessibilityCustomActionsURLs
        }
        
        // Iterate over results
        for result in results {
            // We only care about links and phone numbers
            switch result.resultType {
                
            case .link:
                guard let url = result.url else {
                    continue
                }

                let actionOpen =
                    UIAccessibilityCustomAction(
                        name: String.localizedStringWithFormat(
                            #localize("accessibility_action_open_link"),
                            attributedText.attributedSubstring(from: result.range).string
                        )
                    ) { _ in
                        openURLHandler(url)
                        return true
                    }
                accessibilityCustomActionsURLs.append((result.range, actionOpen))
                    
            case .phoneNumber:
                guard let phoneNumber = result.phoneNumber else {
                    continue
                }
                    
                let cleanString = phoneNumber.replacingOccurrences(of: "\u{00A0}", with: "")
                guard let encodedString = cleanString
                    .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed),
                    let phoneURL = URL(string: String(format: "tel:%@", encodedString)) else {
                    continue
                }
                    
                let actionOpen =
                    UIAccessibilityCustomAction(
                        name: String.localizedStringWithFormat(
                            #localize("accessibility_action_call_phone"),
                            attributedText.attributedSubstring(from: result.range).string
                        )
                    ) { _ in
                        openURLHandler(phoneURL)
                        return true
                    }
                accessibilityCustomActionsURLs.append((result.range, actionOpen))

            default:
                continue
            }
        }
        
        return accessibilityCustomActionsURLs
    }
    
    private func checkForMentions(
        in attributedString: NSAttributedString,
        openDetailsHandler: @escaping (String) -> Void
    ) -> [(NSRange, UIAccessibilityCustomAction)] {
        
        let range = NSRange(location: 0, length: attributedText.length)
        var accessibilityCustomActionsMentions = [(NSRange, UIAccessibilityCustomAction)]()
        
        attributedText.enumerateAttributes(in: range) { attributes, subrange, _ in
            
            // We only care if the subrange is of mention type and link
            guard (
                attributes.contains { $0.key == NSAttributedString.Key.tokenType } && attributes
                    .contains { $0.key == NSAttributedString.Key.link }
            ) else {
                return
            }
            
            guard let mentionString = attributes[NSAttributedString.Key.link] as? String else {
                return
            }
            
            let id = String(mentionString.suffix(8))
            
            guard id.count == 8 else {
                return
            }
            
            // Exclude @All
            guard id != "@@@@@@@@" else {
                return
            }
            
            let actionOpen =
                UIAccessibilityCustomAction(
                    name: String.localizedStringWithFormat(
                        #localize("accessibility_action_open_mention"),
                        attributedText.attributedSubstring(from: subrange).string
                    )
                ) { _ in
                    openDetailsHandler(id)
                    return true
                }
            accessibilityCustomActionsMentions.append((subrange, actionOpen))
        }
        
        return accessibilityCustomActionsMentions
    }
    
    private func checkForCheckingResults(in attributedString: NSAttributedString) -> [NSTextCheckingResult]? {
        var typesToCheck: NSTextCheckingResult.CheckingType = .link
        
        if UIApplication.shared.canOpenURL(URL(string: "tel:0")!) {
            typesToCheck.insert(.phoneNumber)
        }
        
        var results = [NSTextCheckingResult]()
        
        do {
            let dataDetector = try NSDataDetector(types: typesToCheck.rawValue)
            
            dataDetector.enumerateMatches(
                in: attributedString.string,
                range: NSRange(location: 0, length: attributedString.length)
            ) { result, _, _ in
                guard let result else {
                    return
                }
                results.append(result)
            }
        }
        catch {
            return nil
        }
        return results
    }
}

// MARK: - UITextViewDelegate

extension MessageTextView: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        guard IDNASafetyHelper.isLegalURL(url: URL, viewController: AppDelegate.shared().currentTopViewController())
        else {
            return false
        }
        if URL.absoluteString.starts(with: "ThreemaId:") {
            if interaction == .invokeDefaultAction {
                let threemaID = String(URL.absoluteString.suffix(8))
                
                guard let messageTextViewDelegate else {
                    let msg = "messageTextViewDelegate is unexpectedly nil"
                    assertionFailure(msg)
                    DDLogError("\(msg)")
                    return false
                }
                
                messageTextViewDelegate.showContact(identity: threemaID)
            }
            return false
        }
        else if URL.scheme == "http" || URL.scheme == "https",
                URL.host?.lowercased() == "threema.id",
                interaction == .invokeDefaultAction {
            URLHandler.handleThreemaDotIDURL(URL, hideAppChooser: false)
            return false
        }
        return true
    }
    
    func textView(
        _ textView: UITextView,
        shouldInteractWith textAttachment: NSTextAttachment,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        false
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        guard selectedTextRange != nil else {
            messageTextViewDelegate?.didSelectText(in: nil)
            return
        }
        messageTextViewDelegate?.didSelectText(in: self)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension MessageTextView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard !isTapLocationOnLink(location: otherGestureRecognizer.location(in: self)) else {
            return false
        }
        
        if (
            otherGestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer
                .name == "ThreemaLongPressContextMenuGestureRecognizer"
        ) ||
            otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard !isTapLocationOnLink(location: otherGestureRecognizer.location(in: self)) else {
            return false
        }
        
        if (
            otherGestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer
                .name == "ThreemaLongPressContextMenuGestureRecognizer"
        ) ||
            otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    private func isTapLocationOnLink(location: CGPoint) -> Bool {
        guard let textPosition: UITextPosition = closestPosition(to: location) else {
            return false
        }
        
        guard let textRange: UITextRange = tokenizer.rangeEnclosingPosition(
            textPosition,
            with: UITextGranularity.word,
            inDirection: UITextDirection(rawValue: 1)
        ) else {
            return false
        }

        let location = offset(from: beginningOfDocument, to: textRange.start)
        let length = offset(from: textRange.start, to: textRange.end)
        let range = NSRange(location: location, length: length)
        
        var isLink = false
        attributedText.enumerateAttributes(in: range) { attributes, _, _ in
            isLink = attributes.contains { $0.key == NSAttributedString.Key.link }
        }
        
        return isLink
    }
}
