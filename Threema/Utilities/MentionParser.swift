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

class MentionParser {
    private static let BOUNDARY_PATTERN = "[\\s.,!?¡¿‽⸮;:&(){}\\[\\]⟨⟩‹›«»'\"‘’“”*~\\-_…⋯᠁]"
    private static let URL_BOUNDARY_PATTERN = "[a-zA-Z0-9\\-._~:/?#\\[\\]@!$&'()*+,;=%]"
    private static let URL_START_PATTERN = "^([a-zA-Z]+://.*)|([(w|W)]{3}.*)"
    
    private static let MARKUP_CHAR_BOLD = "*"
    private static let MARKUP_CHAR_ITALIC = "_"
    private static let MARKUP_CHAR_STRIKETHROUGH = "~"
    private static let MARKUP_CHAR_PATTERN = ".*[\\*_~].*"
    
    private static let markupAttributes = [
        NSAttributedString.Key.foregroundColor: Colors.textVeryLight,
        NSAttributedString.Key.tokenType: TokenType.markup,
    ] as [NSAttributedString.Key: Any]
    
    private struct Token {
        let kind: ParseTokenType
        let start: Int
        let end: Int
    }
    
    private struct AttributedItem {
        let kind: ParseTokenType
        let textStart: Int
        let textLength: Int
        let textEnd: Int
        let markerStart: Int?
        let markerEnd: Int?
    }
    
    /// Errors for `ThreemaPushNotification` parsing
    enum MarkupParserError: Error, Equatable {
        case emptyStack(String)
        case unknownTokenOnStack(String)
        case invalidTokenKind(String)
    }
    
    enum TokenType {
        case bold
        case italic
        case strikethrough
        case boldItalic
        case markup
        case url
    }
    
    private enum ParseTokenType {
        case text
        case newLine
        case asterisk
        case underscore
        case tilde
        case url
        
        func attributes(font: UIFont) -> [NSAttributedString.Key: Any]? {
            switch self {
            case .asterisk:
                [
                    NSAttributedString.Key.font: UIFont.systemFont(fontSize: font.pointSize, traits: [.traitBold])!,
                    NSAttributedString.Key.tokenType: TokenType.bold,
                ]
            case .underscore:
                [
                    NSAttributedString.Key.font: UIFont.systemFont(fontSize: font.pointSize, traits: [.traitItalic])!,
                    NSAttributedString.Key.tokenType: TokenType.italic,
                ]
            case .tilde:
                [
                    NSAttributedString.Key.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    NSAttributedString.Key.tokenType: TokenType.strikethrough,
                ]
            case .url:
                [NSAttributedString.Key.foregroundColor: Colors.primary]
            default:
                nil
            }
        }
    }

    private let markupChars: [ParseTokenType: String] = {
        var markups = [ParseTokenType: String]()
        markups.updateValue(MARKUP_CHAR_BOLD, forKey: ParseTokenType.asterisk)
        markups.updateValue(MARKUP_CHAR_ITALIC, forKey: ParseTokenType.underscore)
        markups.updateValue(MARKUP_CHAR_STRIKETHROUGH, forKey: ParseTokenType.tilde)
        return markups
    }()
        
    private let boundaryPattern: NSRegularExpression? = {
        guard let regex = try? NSRegularExpression(pattern: BOUNDARY_PATTERN, options: [.caseInsensitive]) else {
            return nil
        }
        return regex
    }()
    
    private let urlBoundaryPattern: NSRegularExpression? = {
        guard let regex = try? NSRegularExpression(pattern: URL_BOUNDARY_PATTERN, options: [.caseInsensitive]) else {
            return nil
        }
        return regex
    }()
    
    private let urlStartPattern: NSRegularExpression? = {
        guard let regex = try? NSRegularExpression(pattern: URL_START_PATTERN, options: [.caseInsensitive]) else {
            return nil
        }
        return regex
    }()
}

// MARK: - public functions

extension MarkupParser {
    func markify(
        attributedString: NSAttributedString,
        font: UIFont,
        parseURL: Bool = true,
        removeMarkups: Bool = false
    ) -> NSAttributedString {
        let parsedMarkups = NSMutableAttributedString(attributedString: attributedString)
        do {
            try parse(
                allTokens: tokenize(text: parsedMarkups.string, parseURL: parseURL),
                attributedString: parsedMarkups,
                font: font
            )
            if removeMarkups {
                return removeMarkupsFromParse(parsed: parsedMarkups)
            }
            return parsedMarkups
        }
        catch {
            DDLogVerbose(error.localizedDescription)
            return parsedMarkups
        }
    }
    
    func removeMarkupsFromParse(parsed: NSAttributedString) -> NSAttributedString {
        let parsedWithoutMarkups = NSMutableAttributedString(attributedString: parsed)
        parsedWithoutMarkups
            .enumerateAttributes(in: NSRange(
                location: 0,
                length: parsedWithoutMarkups.length
            )) { attributes, range, _ in
                // check is attribute markup and remove it from parsed string
                if attributes[NSAttributedString.Key.tokenType] as? MarkupParser.TokenType == TokenType.markup {
                    parsedWithoutMarkups.deleteCharacters(in: range)
                }
            }
        return parsedWithoutMarkups
    }
}

// MARK: - private functions

extension MarkupParser {
    private func tokenPresenceMap() -> [ParseTokenType: Bool] {
        var map = [ParseTokenType: Bool]()
        map.updateValue(false, forKey: .asterisk)
        map.updateValue(false, forKey: .underscore)
        map.updateValue(false, forKey: .tilde)
        return map
    }
    
    /// Returns the bold italic font for the given font
    /// - Parameter font: The given font
    /// - Returns: Returns the bold italic font for the given font
    private func italicBoldAttributes(font: UIFont) -> [NSAttributedString.Key: Any] {
        if let attributedFont = UIFont.systemFont(fontSize: font.pointSize, traits: [.traitBold, .traitItalic]) {
            return [NSAttributedString.Key.font: attributedFont, NSAttributedString.Key.tokenType: TokenType.boldItalic]
        }
        return [NSAttributedString.Key.tokenType: TokenType.boldItalic]
    }

    /// Return whether the specified token type is a markup token.
    /// - Parameter tokenType: The token type of the given text
    /// - Returns: Is given TokenType a markup token
    private func isMarkupToken(tokenType: ParseTokenType) -> Bool {
        markupChars.keys.contains(tokenType)
    }
    
    /// Return whether the character at the specified position in the string is a boundary character.
    /// When `character` is out of range, the function will return true.
    /// - Parameters:
    ///   - text: The given text
    ///   - position: Specified position in the string
    /// - Returns: Is boundary character
    private func isBoundary(text: String, position: Int) -> Bool {
        if position < 0 || position >= text.count {
            return true
        }
       
        guard let result = boundaryPattern?.matches(
            in: text,
            options: NSRegularExpression.MatchingOptions(rawValue: 0),
            range: NSRange(location: position, length: 1)
        ) else {
            return true
        }
        return !result.isEmpty
    }
    
    /// Return whether the specified character is a URL boundary character.
    /// When `character` is undefined, the function will return true.
    /// - Parameters:
    ///   - text: The given text
    ///   - position: Specified position in the string
    /// - Returns:  Is boundary character
    private func isURLBoundary(text: String, position: Int) -> Bool {
        if position < 0 || position >= text.count {
            return true
        }
        guard let result = urlBoundaryPattern?.matches(
            in: text,
            options: NSRegularExpression.MatchingOptions(rawValue: 0),
            range: NSRange(location: position, length: 1)
        ) else {
            return true
        }
        return result.isEmpty
    }
    
    /// Return whether the specified string starts an URL.
    /// - Parameters:
    ///   - text: The given text
    ///   - position: Specified position in the string
    /// - Returns: Starts an URL
    private func isURLStart(text: String, position: Int) -> Bool {
        if position < 0 || position >= text.count {
            return false
        }
        guard let result = urlStartPattern?.matches(
            in: text,
            options: NSRegularExpression.MatchingOptions(rawValue: 0),
            range: NSRange(location: position, length: text.count - position)
        ) else {
            return false
        }
        for res in result {
            if res.range.location == position {
                return true
            }
        }
        return false
    }
    
    /// Add text token and increase the token length
    /// - Parameters:
    ///   - tokenLength: Current token length (inout)
    ///   - tokenLengthMinus: When the token length at the end should be substracted
    ///   - i: The given index
    ///   - tokens: Array with all tokens (inout)
    /// - Returns: The new token length
    private func pushTextToken(
        tokenLength: inout Int,
        tokenLengthMinus: Int = 0,
        i: Int,
        tokens: inout [Token],
        isURL: Bool = false
    ) -> Int {
        if tokenLength - tokenLengthMinus > 0 {
            tokens
                .append(Token(
                    kind: isURL ? .url : .text,
                    start: i - tokenLength - tokenLengthMinus,
                    end: isURL ? i + 1 : i
                ))
            tokenLength = 0
        }
        return tokenLength - tokenLengthMinus
    }
    
    /// Find all tokens and return the token array
    /// - Parameter text: Text to search for all tokens
    /// - Returns: The founded tokens
    private func tokenize(text: String, parseURL: Bool) -> [Token] {
        var tokenLength = 0
        var matchingURL = false
        var tokens = [Token]()
        
        for (index, char) in text.enumerated() {
            // Detect URLs
            if !matchingURL {
                matchingURL = isURLStart(text: text, position: index)
                if matchingURL, parseURL {
                    tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                }
            }
            
            // URLs have a limited set of boundary characters, therefore we need to
            // treat them separately.
            if matchingURL {
                if isURLBoundary(text: text, position: index + 1) {
                    tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens, isURL: parseURL)
                    matchingURL = false
                }
                tokenLength += 1
            }
            else {
                let prevIsBoundary = isBoundary(text: text, position: index - 1)
                let nextIsBoundary = isBoundary(text: text, position: index + 1)
                
                let currentCharacter = String(char)
                if currentCharacter == MarkupParser.MARKUP_CHAR_BOLD, prevIsBoundary || nextIsBoundary {
                    tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                    tokens.append(Token(kind: .asterisk, start: index, end: index + 1))
                }
                else if currentCharacter == MarkupParser.MARKUP_CHAR_ITALIC, prevIsBoundary || nextIsBoundary {
                    tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                    tokens.append(Token(kind: .underscore, start: index, end: index + 1))
                }
                else if currentCharacter == MarkupParser.MARKUP_CHAR_STRIKETHROUGH, prevIsBoundary || nextIsBoundary {
                    tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                    tokens.append(Token(kind: .tilde, start: index, end: index + 1))
                }
                else if char.isNewline {
                    tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                    tokens.append(Token(kind: .newLine, start: index, end: index + 1))
                }
                else {
                    tokenLength += 1
                }
            }
        }
        _ = pushTextToken(tokenLength: &tokenLength, tokenLengthMinus: 1, i: text.count - 1, tokens: &tokens)
        
        return tokens
    }
    
    /// Apply all attributes to the attributed string
    /// - Parameters:
    ///   - attributedString: The given attributed string
    ///   - attributedStack: All attributed items
    ///   - font: The font of the textView
    private func applyAttributes(
        attributedString: NSMutableAttributedString,
        attributedStack: [AttributedItem],
        font: UIFont
    ) {
        var doubleAttributes = [NSRange]()
        var stack = attributedStack
        while !stack.isEmpty {
            if let attributedItem = stack.popLast() {
                if attributedItem.textStart > attributedItem.textEnd {
                    DDLogNotice("MarkupParser: range problem. Ignore")
                }
                else {
                    if attributedItem.textStart >= 0, attributedItem.textEnd < attributedString.length {
                        if attributedItem.textStart != attributedItem.textEnd {
                            if let start = attributedItem.markerStart {
                                attributedString.addAttributes(
                                    MarkupParser.markupAttributes,
                                    range: NSRange(location: start, length: 1)
                                )
                            }
                            if let markupAttributes = attributedItem.kind.attributes(font: font) {
                                if attributedItem.kind == .asterisk || attributedItem.kind == .underscore {
                                    // check is font already italic
                                    attributedString
                                        .enumerateAttributes(in: NSRange(
                                            location: attributedItem.textStart,
                                            length: attributedItem.textLength
                                        )) { attributes, range, _ in
                                            // check is attribute bold or italic
                                            if attributes.keys.contains(NSAttributedString.Key.font) {
                                                // to handle bold and italic
                                                doubleAttributes.append(range)
                                            }
                                        }
                                }
                                
                                attributedString.addAttributes(
                                    markupAttributes,
                                    range: NSRange(
                                        location: attributedItem.textStart,
                                        length: attributedItem.textLength
                                    )
                                )
                            }
                            if let end = attributedItem.markerEnd {
                                attributedString.addAttributes(
                                    MarkupParser.markupAttributes,
                                    range: NSRange(location: end, length: 1)
                                )
                            }
                        }
                    }
                }
            }
        }
        
        // add all bold-italic attributes
        for range in doubleAttributes {
            attributedString.addAttributes(
                italicBoldAttributes(font: font),
                range: NSRange(location: range.location, length: range.length)
            )
        }
    }
    
    /// Parse the given tokens into the attributed string
    /// - Parameters:
    ///   - allTokens: Array with all found tokens
    ///   - attributedString: The attributed string to add the formatting
    ///   - font: The font of the textView
    /// - Throws: MarkupParserError
    private func parse(allTokens: [Token], attributedString: NSMutableAttributedString, font: UIFont) throws {
        let tokens = allTokens
        var stack = [Token]()
        var attributedStack = [AttributedItem]()
        var tokenPresenceMap = tokenPresenceMap()
        
        for token in tokens {
            switch token.kind {
            case .text:
                // Keep text/url as-is
                stack.append(token)
            case .url:
                attributedStack.append(AttributedItem(
                    kind: token.kind,
                    textStart: token.start,
                    textLength: token.end - token.start,
                    textEnd: token.end,
                    markerStart: nil,
                    markerEnd: nil
                ))
            case .asterisk, .underscore, .tilde:
                // Optimization: Only search the stack if a token with this token type exists
                if let value = tokenPresenceMap[token.kind], value {
                    // Pop tokens from the stack. If a matching token was found, apply
                    // markup to the text parts in between those two tokens.
                    var textParts = [Token]()
                    while true {
                        if let stackTop = stack.popLast() {
                            if stackTop.kind == .text {
                                textParts.append(stackTop)
                            }
                            else if stackTop.kind == token.kind {
                                var start = 0
                                var end = 0
                                
                                if textParts.isEmpty {
                                    start = stackTop.end
                                    end = stackTop.end
                                }
                                else {
                                    if let t = textParts.last {
                                        start = t.start
                                    }
                                    if let t = textParts.first {
                                        end = t.end
                                    }
                                }
                                attributedStack.append(AttributedItem(
                                    kind: token.kind,
                                    textStart: start,
                                    textLength: end - start,
                                    textEnd: end,
                                    markerStart: stackTop.start,
                                    markerEnd: token.start
                                ))
                                stack.append(Token(kind: .text, start: start, end: end))
                                tokenPresenceMap.updateValue(false, forKey: token.kind)
                                break
                            }
                            else if isMarkupToken(tokenType: stackTop.kind) {
                                textParts.append(Token(kind: .text, start: stackTop.start, end: stackTop.end))
                            }
                            else {
                                throw MarkupParserError.unknownTokenOnStack("Unknown token on stack: \(token.kind)")
                            }
                            tokenPresenceMap.updateValue(false, forKey: stackTop.kind)
                        }
                    }
                }
                else {
                    stack.append(token)
                    tokenPresenceMap.updateValue(true, forKey: token.kind)
                }
            case .newLine:
                tokenPresenceMap = self.tokenPresenceMap()
            default:
                throw MarkupParserError.invalidTokenKind("Invalid token kind: \(token.kind)")
            }
        }
        
        applyAttributes(attributedString: attributedString, attributedStack: attributedStack, font: font)
    }
}

extension NSAttributedString.Key {
    static let tokenType: NSAttributedString.Key = .init("tokenType")
}
