//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import UIKit

/// An implementation of NSTextStorage which formats the text using our MarkupParser
class MarkupParsingTextStorage: NSTextStorage {
    // MARK: Private Properties
    
    // MARK: Internal State

    private var backingStore = NSTextStorage()
    
    private lazy var markupParser = MarkupParser()
    
    // These two help set the cursor to the correct position in `ChatTextView.textViewDidChange(textView)`
    // even when we change the text length e.g. when inserting mentions.
    private(set) var lastReplacementRange: NSRange?
    private(set) var lastTextChange: String?

    // MARK: Required Proprerties
    
    override var string: String {
        backingStore.string
    }
    
    // MARK: Lifecycle
    
    override init() {
        super.init()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Required Functions
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        // This workaround shouldn't be necessary. If `edited` is set correctly range is always smaller than the length
        // of the backing store. However when typing inside a mention effectively deleting the mention and inserting one
        // character this doesn't seem to hold.
        //
        // It is unclear why this happens and it is likely that it is because of a bug in our code.
        // But this workaround fixes the crashes caused by it without introducing any obvious downsides.
        guard location <= backingStore.length else {
            range?.pointee = NSRange(location: location, length: 0)
            return [
                NSAttributedString.Key.foregroundColor: Colors.text,
                NSAttributedString.Key.font: UIFont
                    .preferredFont(forTextStyle: ChatViewConfiguration.ChatTextView.textStyle),
            ]
        }
        
        return backingStore.attributes(at: location, effectiveRange: range)
    }
  
    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        defer { endEditing() }
        
        // Adjust the range for mentions which are treated as single unit
        let currentReplacementRange = MarkupParsingTextStorage.currentReplacementRange(
            range: range,
            oldParsedText: backingStore
        )
        
        // Store current state for access by `ChatTextView.textViewDidChange(textView)`
        lastReplacementRange = currentReplacementRange
        lastTextChange = str
        
        backingStore.replaceCharacters(in: currentReplacementRange, with: NSAttributedString(string: str))
        
        let adjustedStringLength = str.utf16.count
        
        edited(
            .editedCharacters,
            range: currentReplacementRange,
            changeInLength: adjustedStringLength - currentReplacementRange.length
        )
    }
        
    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        // Workaround
        /// This workaround shouldn't be necessary. If `edited` is set correctly range is always smaller than the length
        /// of the backing store.
        /// However when typing inside a mention effectively deleting the mention and inserting one character this
        /// doesn't seem to hold.
        /// It is unclear why this happens and it is likely that it is because of a bug in our code.
        /// But this workaround fixes the crashes caused by it without introducing any obvious downsides.
        guard range.upperBound <= backingStore.length else {
            return
        }
        
        // Workaround
        /// Usually we want to keep the typing attributes we have set in textView but if the last character
        /// was a markup token we want to keep the grey color instead of having it reset to the typing attributes.
        var newRange = NSRange(location: range.location, length: range.length)
        if range.length == 1,
           backingStore.length > 1,
           let currentFont = backingStore
           .attributes(
               at: range.upperBound - 1,
               effectiveRange: &newRange
           )[NSAttributedString.Key.foregroundColor] as? UIColor,
           let newFont = attrs?[.foregroundColor] as? UIColor,
           currentFont != newFont {
            parseAndUpdateBackingStore()
            return
        }
        
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
    
    // MARK: Overrides
    
    override func processEditing() {
        parseAndUpdateBackingStore()
        super.processEditing()
    }
    
    // MARK: Accessing internal state
    
    ///
    /// - Returns: The current text with raw mentions
    public func getRawText() -> NSAttributedString {
        markupParser.parseMentionNamesToMarkup(parsed: backingStore)
    }
    
    /// Gets the text using `getRawText` and removes the current text from the backing store
    /// - Returns: The current text with raw mentions
    public func removeCurrentText() -> String? {
        beginEditing()
        defer { endEditing() }
        let rawText = getRawText()
        guard rawText.string != "" else {
            return nil
        }
        
        replaceCharacters(in: NSRange(location: 0, length: backingStore.length), with: "")
        return rawText.string
    }
    
    /// Reformats the whole text
    ///
    /// Used when font size or color should change
    public func reformatText() {
        replaceCharacters(in: NSRange(location: 0, length: 0), with: "")
    }
    
    /// Used instead of direct assignment to `text` or `attributedText` in `ChatTextView
    /// Replaces the current text
    /// - Parameter text: the text to set in the store
    public func replaceAndParse(_ text: String) {
        replaceCharacters(in: NSRange(location: 0, length: backingStore.length), with: text)
    }
    
    // MARK: Private Helper Functions
    
    private func parseAndUpdateBackingStore() {
        beginEditing()
        defer { endEditing() }
        
        let notParsedText = markupParser.parseMentionNamesToMarkup(parsed: backingStore)
        
        let attributedString = NSAttributedString(
            string: notParsedText.string,
            attributes: [
                NSAttributedString.Key.foregroundColor: Colors.text,
                NSAttributedString.Key.font: UIFont
                    .preferredFont(forTextStyle: ChatViewConfiguration.ChatTextView.textStyle),
            ]
        )
        
        let prevLength = backingStore.length
        
        backingStore.setAttributedString(markupParser.markify(
            attributedString: attributedString,
            font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body),
            parseMention: true,
            forTextStorage: true
        ))
        
        if !backingStore.string.isEmpty {
            let textAlignment = backingStore.string.textAlignment
            let writingDirection: NSWritingDirection
            
            switch textAlignment {
            case .right: writingDirection = .rightToLeft
            case .left: writingDirection = .leftToRight
            case .natural, .center, .justified: writingDirection = .natural
            @unknown default: writingDirection = .natural
            }
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.baseWritingDirection = writingDirection
            
            backingStore.addAttributes(
                [.paragraphStyle: paragraphStyle],
                range: NSRange(location: 0, length: backingStore.length)
            )
        }
        
        edited(
            .editedCharacters,
            range: NSRange(location: 0, length: prevLength),
            changeInLength: backingStore.length - prevLength
        )
        edited(
            .editedAttributes,
            range: NSRange(location: 0, length: backingStore.length),
            changeInLength: 0
        )
    }
    
    private static func currentReplacementRange(range: NSRange, oldParsedText: NSAttributedString) -> NSRange {
        guard range.location < oldParsedText.length else {
            return range
        }
           
        var currentReplacementRange = range
        var foundTokenRange = NSRange()
        let searchToken = NSAttributedString.Key.contact
           
        if range.length == 0,
           oldParsedText.attribute(
               searchToken,
               at: range.location,
               longestEffectiveRange: &foundTokenRange,
               in: NSRange(location: 0, length: oldParsedText.length)
           ) != nil,
           range.location != foundTokenRange.location {
            currentReplacementRange = NSUnionRange(currentReplacementRange, foundTokenRange)
        }
        else {
            // search the range for any instances of the desired text attribute
            oldParsedText.enumerateAttribute(
                NSAttributedString.Key.tokenType,
                in: range,
                using: { attribute, attributedRange, _ in
                    
                    guard let attribute = attribute as? MarkupParser.TokenType,
                          attribute == MarkupParser.TokenType.mention else {
                        return
                    }
                    
                    // get the attribute's full range and merge it with the original
                    if oldParsedText.attribute(
                        searchToken,
                        at: attributedRange.location,
                        longestEffectiveRange: &foundTokenRange,
                        in: NSRange(location: 0, length: oldParsedText.length)
                    ) != nil {
                        currentReplacementRange = NSUnionRange(currentReplacementRange, foundTokenRange)
                    }
                }
            )
        }

        return currentReplacementRange
    }
}
