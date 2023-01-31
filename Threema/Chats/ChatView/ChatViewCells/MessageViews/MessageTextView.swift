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

import CocoaLumberjackSwift
import ThreemaFramework
import UIKit

protocol MessageTextViewDelegate: AnyObject {
    var currentSearchText: String? { get }

    func showContact(identity: String)
    func didSelectText(in textView: MessageTextView?)
}

extension MessageTextViewDelegate {
    func showContact(identity: String) {
        // This is a empty implementation to allow this method to be optional
    }
}

/// Label with correct font for a text message or caption
///
/// With IOS-2392 this will automatically format text and show big emojis if enabled.
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
            let currentSearchTextRenderState: SearchTextRenderState
            if let searchText {
                currentSearchTextRenderState = (searchText == currentSearchText) ? .textUnchanged : .textChanged
            }
            else {
                currentSearchTextRenderState = .empty
            }
            
            guard currentText == newText else {
                DDLogVerbose("Text Unchanged")
                return .textChanged(currentSearchTextRenderState)
            }
            DDLogVerbose("Text changed")
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
                    // If the search text has changed we need to do a full markify round because we don't know what exactly has changed
                    // and then highlight the text again.
                    setAttributedText(to: markify(newValue), maybeHighlighting: currentSearchText)
                case .textUnchanged:
                    // This only happens when searching
                    //
                    // Even if both text and search text are unchanged we need to re-markify this text because
                    // of Colors overwriting our previously set colors. See `updateColors` of this class for the other part of the workaround
                    // where we set text to the same value again.
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
        updateColors()
    }
    
    required init?(coder: NSCoder, messageTextViewDelegate: MessageTextViewDelegate) {
        self.messageTextViewDelegate = messageTextViewDelegate
        super.init(coder: coder)
        configureTextView()
        updateColors()
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
        adjustsFontForContentSizeCategory = true
        isScrollEnabled = false
        isEditable = false
        isSelectable = true
        dataDetectorTypes = [.link, .phoneNumber]
        isUserInteractionEnabled = true
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.lineFragmentPadding = 0.0
        delegate = self
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }
        
    // MARK: - Update
    
    func updateColors() {
        Colors.setTextColor(Colors.text, in: self)
        if messageTextViewDelegate?.currentSearchText != nil {
            // Works around `Colors` resetting our colors when we actually want to highlight text
            text = text
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
        
        if text.containsOnlyEmoji,
           text.emojis.count <= 3 {
            return NSAttributedString(
                string: text,
                attributes: [
                    NSAttributedString.Key.foregroundColor: Colors.text,
                    NSAttributedString.Key.font: UIFont
                        .preferredFont(forTextStyle: ChatViewConfiguration.Text.emojiTextStyle),
                ]
            )
        }
        else {
            let attributedString = NSAttributedString(
                string: text,
                attributes: [
                    NSAttributedString.Key.foregroundColor: Colors.text,
                    NSAttributedString.Key.font: UIFont
                        .preferredFont(forTextStyle: ChatViewConfiguration.Text.textStyle),
                ]
            )
            return markupParser.markify(
                attributedString: attributedString,
                font: UIFont.preferredFont(forTextStyle: ChatViewConfiguration.Text.textStyle),
                removeMarkups: true
            ) as! NSMutableAttributedString
        }
    }
    
    func resetTextSelection() {
        selectedTextRange = nil
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
        guard IDNSafetyHelper.isLegalURL(url: URL, viewController: AppDelegate.shared().currentTopViewController())
        else {
            return false
        }
        if URL.absoluteString.starts(with: "ThreemaId:") {
            if interaction == .invokeDefaultAction {
                let threemaID = String(URL.absoluteString.suffix(8))
                
                guard let messageTextViewDelegate = messageTextViewDelegate else {
                    let msg = "messageTextViewDelegate is unexpectedly nil"
                    assertionFailure(msg)
                    DDLogError(msg)
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
