//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import ThreemaFramework
import UIKit

protocol MessageTextViewDelegate: AnyObject {
    func showContact(identity: String)
}

extension MessageTextViewDelegate {
    func showContact(identity: String) {
        // This is a empty implementation to allow this method to be optional
    }
}

/// Label with correct font for a text message or caption
///
/// With IOS-2392 this will automatically format text and show big emojis if enabled.
final class MessageTextView: UITextView {
    
    /// Delegate used to handle cell delegates
    private var messageTextViewDelegate: MessageTextViewDelegate
    
    private lazy var markupParser = MarkupParser()
    
    /// It will parse the string and will set automaticly the attributed text
    override public var text: String! {
        get {
            super.text
        }
        set {
            guard let newValue = newValue else {
                super.text = nil
                return
            }
            if newValue.containsOnlyEmoji,
               newValue.emojis.count <= 3 {
                attributedText = NSAttributedString(
                    string: newValue,
                    attributes: [
                        NSAttributedString.Key.foregroundColor: Colors.text,
                        NSAttributedString.Key.font: ChatViewConfiguration.Text.emojiFont,
                    ]
                )
            }
            else {
                let attributedString = NSAttributedString(
                    string: newValue,
                    attributes: [
                        NSAttributedString.Key.foregroundColor: Colors.text,
                        NSAttributedString.Key.font: ChatViewConfiguration.Text.font,
                    ]
                )
                attributedText = markupParser.markify(
                    attributedString: attributedString,
                    font: ChatViewConfiguration.Text.font,
                    removeMarkups: true
                ) as! NSMutableAttributedString
            }
        }
    }
        
    // MARK: - Lifecycle

    init(frame: CGRect, textContainer: NSTextContainer?, messageTextViewDelegate: MessageTextViewDelegate) {
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
    
    convenience init(messageTextViewDelegate: MessageTextViewDelegate) {
        self.init(frame: .zero, textContainer: nil, messageTextViewDelegate: messageTextViewDelegate)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureTextView() {
        font = ChatViewConfiguration.Text.font
        adjustsFontForContentSizeCategory = true
        isScrollEnabled = false
        isEditable = false
        isSelectable = true
        isUserInteractionEnabled = true
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.lineFragmentPadding = 0.0
        delegate = self
    }
        
    // MARK: - Update
    
    func updateColors() {
        Colors.setTextColor(Colors.text, in: self)
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
}
