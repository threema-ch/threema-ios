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
import UIKit

public class MarkupParser {
    // MARK: - Nested Types

    private enum MentionType {
        case me
        case all
        case contact(ContactEntity)
    }
    
    private static let BOUNDARY_PATTERN = "[\\s.,!?¡¿‽⸮;:&(){}\\[\\]⟨⟩‹›«»'\"‘’“”*~\\-_…⋯᠁]"
    private static let URL_BOUNDARY_PATTERN = "[\(MarkupParser.RTLO)a-zA-Z0-9\\-.äöü_~:/?#\\[\\]@!$&'()*+,;=%]"
    private static let URL_START_PATTERN = #"([a-zA-Z]+:\/\/)|([wW]{3}.)"#
    private static let MENTION_PATTERN = "@\\[([A-Z0-9*]{1}[A-Z0-9]{7}|@{8})\\]"
    
    private static let MARKUP_CHAR_BOLD = "*"
    private static let MARKUP_CHAR_ITALIC = "_"
    private static let MARKUP_CHAR_STRIKETHROUGH = "~"
    
    private static let RTLO = String(unicodeScalarLiteral: UnicodeScalarType("u202E"))
    
    private static let MENTION_ALL = "@@@@@@@@"
    
    private static let PREFORMAT_MAX_COUNT = 5000
    
    private static let markupAttributes = [
        NSAttributedString.Key.foregroundColor: Colors.textVeryLight,
        NSAttributedString.Key.tokenType: TokenType.markup,
    ] as [NSAttributedString.Key: Any]
    
    private struct Token {
        let kind: ParseTokenType
        let start: Int
        let end: Int
        let link: String?
        
        init(kind: ParseTokenType, start: Int, end: Int, link: String? = nil) {
            self.kind = kind
            self.start = start
            self.end = end
            self.link = link
        }
    }
    
    private struct AttributedItem {
        let kind: ParseTokenType
        let textStart: Int
        let textLength: Int
        let textEnd: Int
        let markerStart: Int?
        let markerEnd: Int?
        let link: String?
        
        init(
            kind: ParseTokenType,
            textStart: Int,
            textLength: Int,
            textEnd: Int,
            markerStart: Int? = nil,
            markerEnd: Int? = nil,
            link: String? = nil
        ) {
            self.kind = kind
            self.textStart = textStart
            self.textLength = textLength
            self.textEnd = textEnd
            self.markerStart = markerStart
            self.markerEnd = markerEnd
            self.link = link
        }
    }
    
    /// Errors for `ThreemaPushNotification` parsing
    public enum MarkupParserError: Error, Equatable {
        case emptyStack(String)
        case unknownTokenOnStack(String)
        case invalidTokenKind(String)
    }
    
    public enum TokenType {
        case bold
        case italic
        case strikethrough
        case boldItalic
        case markup
        case url
        case mention
    }
    
    private enum ParseTokenType {
        case text
        case newLine
        case asterisk
        case underscore
        case tilde
        case url
        case mention
        
        func attributes(font: UIFont) -> [NSAttributedString.Key: Any]? {
            switch self {
            case .asterisk:
                return [
                    NSAttributedString.Key.font: UIFont.systemFont(fontSize: font.pointSize, traits: [.traitBold])!,
                    NSAttributedString.Key.tokenType: TokenType.bold,
                ]
            case .underscore:
                return [
                    NSAttributedString.Key.font: UIFont.systemFont(fontSize: font.pointSize, traits: [.traitItalic])!,
                    NSAttributedString.Key.tokenType: TokenType.italic,
                ]
            case .tilde:
                return [
                    NSAttributedString.Key.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    NSAttributedString.Key.tokenType: TokenType.strikethrough,
                ]
            case .url:
                return [
                    NSAttributedString.Key.foregroundColor: UIColor.primary,
                    NSAttributedString.Key.tokenType: TokenType.url,
                ]
            case .mention:
                return [
                    NSAttributedString.Key.foregroundColor: UIColor.primary,
                    NSAttributedString.Key.tokenType: TokenType.mention,
                ]
            default:
                return nil
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
        
    private let mentionPattern: NSRegularExpression? = {
        guard let regex = try? NSRegularExpression(pattern: MENTION_PATTERN, options: [.caseInsensitive]) else {
            return nil
        }
        return regex
    }()
    
    private let highlightColor = UIColor.systemOrange
    
    private lazy var businessInjector = BusinessInjector()
    
    var isURLIndex: [Bool]!
    var isURLStartIndex: [Bool]!
    var isURLBoundaryIndex: [Bool]!
    var isBoundaryIndex: [Bool]!
    var isMentionIndex: [Bool]!
    
    public init() { }
}

// MARK: - Public functions

extension MarkupParser {
    public func markify(
        attributedString: NSAttributedString,
        font: UIFont,
        parseURL: Bool = false,
        parseMention: Bool = true,
        removeMarkups: Bool = false,
        forTextStorage: Bool = false,
        forTests: Bool = false
    ) -> NSAttributedString {
        var parsedMarkups = NSMutableAttributedString(attributedString: attributedString)
        do {
            
            if !forTests {
                parsedMarkups = parseURLWithDataDetectorForLinks(attributedString: parsedMarkups)
            }
            
            try parse(
                allTokens: tokenize(
                    text: parsedMarkups.string,
                    parseURL: parseURL,
                    parseMention: parseMention,
                    forTextStorage: forTextStorage
                ),
                attributedString: parsedMarkups,
                font: font
            )
            let parsedMarkupsAndMentions = parseMentionNames(parsed: parsedMarkups)
            
            if removeMarkups {
                return removeMarkupsFromParse(parsed: parsedMarkupsAndMentions)
            }
            
            return parsedMarkupsAndMentions
        }
        catch {
            DDLogVerbose(error.localizedDescription)
            return parsedMarkups
        }
    }
    
    /// Parse for URL's in the string
    /// - Parameter attributedString: NSMutableAttributedString to parse
    /// - Returns: NSMutableAttributedString with all URL attributes
    public func parseURLWithDataDetectorForLinks(attributedString: NSMutableAttributedString)
        -> NSMutableAttributedString {
        do {
            let dataDetector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            
            dataDetector.enumerateMatches(
                in: attributedString.string,
                range: NSRange(location: 0, length: attributedString.length)
            ) { result, _, _ in
                guard let result else {
                    return
                }
                attributedString.addAttribute(.link, value: result.url ?? "", range: result.range)
            }
            return attributedString
        }
        catch {
            return attributedString
        }
    }
    
    /// Preview string of a string containing markup
    ///
    /// This parses mentions to names and removes markup from a string containing both. Use if if you want just show a
    /// preview string instead of a text containing formatting.
    ///
    /// - Parameter string: String to parse
    /// - Returns: Preview string with all internal markup stripped
    public func previewString(for string: String, font: UIFont) -> NSAttributedString {
        let parsedMarkups = NSMutableAttributedString(string: string)
        
        do {
            try parse(
                allTokens: tokenize(
                    text: parsedMarkups.string,
                    parseURL: false,
                    parseMention: true,
                    forTextStorage: false
                ),
                attributedString: parsedMarkups,
                font: font
            )
        }
        catch {
            DDLogVerbose(error.localizedDescription)
            return parsedMarkups
        }
        
        let parsedMarkupsAndMentions = parseMentionNames(parsed: parsedMarkups)
        let parsedAndRemovedMarkup = removeMarkupsFromParse(parsed: parsedMarkupsAndMentions)
        
        return parsedAndRemovedMarkup
    }
    
    public func parseMentionNamesToMarkup(parsed: NSAttributedString) -> NSAttributedString {
        let parsedWithMentionMarkups = NSMutableAttributedString(attributedString: parsed)
        
        parsedWithMentionMarkups.enumerateAttribute(NSAttributedString.Key.tokenType, in: NSRange(
            location: 0,
            length: parsedWithMentionMarkups.length
        )) { attribute, range, _ in
            guard let attribute = attribute as? MarkupParser.TokenType,
                  attribute == TokenType.mention else {
                return
            }
            var mutableRange = range
            
            let attributes = parsedWithMentionMarkups.attributes(
                at: range.location,
                longestEffectiveRange: &mutableRange,
                in: NSRange(location: 0, length: parsedWithMentionMarkups.length)
            )

            if let mentionType = attributes[NSAttributedString.Key.contact] as? MentionType {
                switch mentionType {
                case .me:
                    if let myIdentity = businessInjector.myIdentityStore.identity {
                        parsedWithMentionMarkups.replaceCharacters(
                            in: range,
                            with: "@[\(myIdentity)]"
                        )
                    }
                    else {
                        DDLogError("Could not set own mention")
                    }
                case .all:
                    parsedWithMentionMarkups.replaceCharacters(in: range, with: "@[\(MarkupParser.MENTION_ALL)]")
                case let .contact(contact):
                    parsedWithMentionMarkups.replaceCharacters(in: range, with: "@[\(contact.identity)]")
                }
            }
        }
       
        return parsedWithMentionMarkups
    }
    
    public func removeMarkupsFromParse(parsed: NSAttributedString) -> NSAttributedString {
        let parsedWithoutMarkups = NSMutableAttributedString(attributedString: parsed)
        parsedWithoutMarkups.enumerateAttribute(NSAttributedString.Key.tokenType, in: NSRange(
            location: 0,
            length: parsedWithoutMarkups.length
        )) { attribute, range, _ in
            // check is attribute markup and remove it from parsed string
            guard let attribute = attribute as? MarkupParser.TokenType,
                  attribute == TokenType.markup else {
                return
            }
            parsedWithoutMarkups.deleteCharacters(in: range)
        }
        return parsedWithoutMarkups
    }
    
    public func parseMentionNames(parsed: NSAttributedString) -> NSAttributedString {

        let parsedWithMentionNames = NSMutableAttributedString(attributedString: parsed)
        
        parsedWithMentionNames.enumerateAttribute(NSAttributedString.Key.tokenType, in: NSRange(
            location: 0,
            length: parsedWithMentionNames.length
        )) { attribute, range, _ in
            guard let attribute = attribute as? MarkupParser.TokenType,
                  attribute == TokenType.mention else {
                return
            }
            var mutableRange = range
            
            let attributes = parsedWithMentionNames.attributes(
                at: range.location,
                longestEffectiveRange: &mutableRange,
                in: NSRange(location: 0, length: parsedWithMentionNames.length)
            )

            if let mentionType = attributes[NSAttributedString.Key.contact] as? MentionType {
                switch mentionType {
                case .me:
                    parsedWithMentionNames.replaceCharacters(
                        in: range,
                        with: "@\(BusinessInjector().myIdentityStore.displayName())"
                    )
                case .all:
                    parsedWithMentionNames.replaceCharacters(
                        in: range,
                        with: "@\(BundleUtil.localizedString(forKey: "all"))"
                    )
                case let .contact(contact):
                    parsedWithMentionNames.replaceCharacters(in: range, with: "@\(contact.displayName)")
                }
            }
        }
       
        return parsedWithMentionNames
    }
    
    public func highlightOccurrences(
        of searchString: String,
        in originalString: NSAttributedString
    ) -> NSAttributedString {
        let mutableOriginalString = NSMutableAttributedString(attributedString: originalString)
        let totalLength = mutableOriginalString.length
        let searchStringLength = NSString(string: searchString).length
        
        var range = NSRange(location: 0, length: mutableOriginalString.length)
        while range.location != NSNotFound {
            range = (mutableOriginalString.string as NSString)
                .range(of: searchString, options: [.caseInsensitive], range: range)
            guard range.location != NSNotFound else {
                continue
            }
            
            mutableOriginalString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: highlightColor,
                range: NSRange(location: range.location, length: searchStringLength)
            )
            
            range = NSRange(
                location: range.location + range.length,
                length: totalLength - (range.location + range.length)
            )
        }
        
        return mutableOriginalString
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
    private func isBoundary(text: String, position: Int, textCount: Int) -> Bool {
        if position < 0 || position >= textCount {
            return true
        }
        
        return isBoundaryIndex[position]
    }
    
    private func setupIsBoundaryCache(text: String, textCount: Int) {
        isBoundaryIndex = [Bool](repeating: false, count: textCount)
        
        guard let isBoundaryCache = boundaryPattern?.matches(
            in: text,
            options: NSRegularExpression.MatchingOptions(rawValue: 0),
            range: NSRange(location: 0, length: textCount)
        ) else {
            return
        }
        
        for item in isBoundaryCache {
            for i in item.range.location..<(item.range.location + item.range.length) {
                isBoundaryIndex[i] = true
            }
        }
    }
    
    /// Return whether the specified character is a URL boundary character.
    /// When `character` is undefined, the function will return true.
    /// - Parameters:
    ///   - text: The given text
    ///   - position: Specified position in the string
    /// - Returns:  Is boundary character
    private func isURLBoundary(text: String, position: Int, textCount: Int) -> Bool {
        if position < 0 || position >= textCount {
            return true
        }
        
        return isURLBoundaryIndex[position]
    }
    
    private func setupIsURLBoundaryCache(text: String, textCount: Int) {
        isURLBoundaryIndex = [Bool](repeating: true, count: textCount)
        
        guard let isURLBoundaryCache = urlBoundaryPattern?.matches(
            in: text,
            options: NSRegularExpression.MatchingOptions(rawValue: 0),
            range: NSRange(location: 0, length: textCount)
        ) else {
            return
        }
        
        for item in isURLBoundaryCache {
            for i in item.range.location..<(item.range.location + item.range.length) {
                isURLBoundaryIndex[i] = false
            }
        }
    }
    
    /// Return whether the specified string starts an URL.
    /// - Parameters:
    ///   - text: The given text
    ///   - position: Specified position in the string
    /// - Returns: Starts an URL
    private func isURLStart(text: String, position: Int, textCount: Int) -> Bool {
        if position < 0 || position >= textCount {
            return false
        }
        
        return isURLIndex[position]
    }
    
    private func setupisURLCache(text: String, textCount: Int) {
        isURLIndex = [Bool](repeating: false, count: textCount)
        
        guard let isURLCache = urlStartPattern?.matches(
            in: text,
            options: NSRegularExpression.MatchingOptions(rawValue: 0),
            range: NSRange(location: 0, length: textCount)
        ) else {
            return
        }
        
        for res in isURLCache {
            isURLIndex[res.range.location] = true
        }
    }
    
    /// Return whether the specified string start an mention
    /// - Parameters:
    ///   - text: The given text
    ///   - position: Specified position in the string
    /// - Returns: Starts an mention
    private func isMention(text: String, position: Int, textCount: Int) -> Bool {
        if position < 0 || position >= textCount {
            return true
        }
        
        return isMentionIndex[position]
    }
    
    private func setupisMentionCache(text: String, textCount: Int) {
        isMentionIndex = [Bool](repeating: false, count: textCount)
        
        guard let isMentionCache = mentionPattern?.matches(
            in: text,
            options: NSRegularExpression.MatchingOptions(rawValue: 0),
            range: NSRange(location: 0, length: textCount)
        ) else {
            return
        }
        
        for item in isMentionCache {
            for i in item.range.location..<(item.range.location + item.range.length) {
                isMentionIndex[i] = true
            }
        }
    }
    
    /// Add text token and increase the token length
    /// - Parameters:
    ///   - tokenLength: Current token length (inout)
    ///   - tokenLengthMinus: When the token length at the end should be substracted
    ///   - i: The given index
    ///   - tokens: Array with all tokens (inout)
    /// - Returns: The new token length
    private func pushTextToken(
        tokenKind: ParseTokenType = .text,
        tokenLength: inout Int,
        i: Int,
        tokens: inout [Token],
        endOfText: Bool = false
    ) -> Int {
        if tokenLength > 0 {
            var calcIndex = i
            if tokenKind == .url {
                calcIndex += 1
            }
            tokens.append(Token(kind: tokenKind, start: i - tokenLength, end: calcIndex))
            tokenLength = 0
        }
        return tokenLength
    }
    
    private func pushURLToken(tokenLength: inout Int, i: Int, tokens: inout [Token], url: String) -> Int {
        if tokenLength > 0 {
            tokens.append(Token(
                kind: .url,
                start: i - tokenLength,
                end: i + 1,
                link: url.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
            ))
            tokenLength = 0
        }
        return tokenLength
    }
    
    /// Find all tokens and return the token array
    /// - Parameter text: Text to search for all tokens
    /// - Returns: The founded tokens
    private func tokenize(text: String, parseURL: Bool, parseMention: Bool, forTextStorage: Bool) -> [Token] {
        var tokenLength = 0
        var matchingURL = false
        var matchingMention = false
        var tokens = [Token]()
        let utf16Text = text.utf16
        let textCount = utf16Text.count
        
        // Initialize Parse Caches
        if forTextStorage,
           textCount >= MarkupParser.PREFORMAT_MAX_COUNT {
            setupisMentionCache(text: text, textCount: textCount)
        }
        else if textCount > 1000 {
            let sema = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .userInteractive).async {
                self.setupisURLCache(text: text, textCount: textCount)
                self.setupIsBoundaryCache(text: text, textCount: textCount)
                sema.signal()
            }
            DispatchQueue.global(qos: .userInteractive).async {
                self.setupisMentionCache(text: text, textCount: textCount)
                self.setupIsURLBoundaryCache(text: text, textCount: textCount)
                sema.signal()
            }
            
            let firstResult = sema.wait(timeout: .now() + .seconds(2))
            let secondResult = sema.wait(timeout: .now() + .seconds(2))
            
            if firstResult == .timedOut {
                DDLogError("[MarkupParser] firstResultTimedOut")
            }
            if secondResult == .timedOut {
                DDLogError("[MarkupParser] secondResultTimedOut")
            }
        }
        else {
            setupisURLCache(text: text, textCount: textCount)
            setupIsBoundaryCache(text: text, textCount: textCount)
            setupisMentionCache(text: text, textCount: textCount)
            setupIsURLBoundaryCache(text: text, textCount: textCount)
        }
        
        if forTextStorage,
           textCount >= MarkupParser.PREFORMAT_MAX_COUNT {
            // Only parse mentions if there are more then 5'000 characters to send
            if let regex = mentionPattern {
                regex.enumerateMatches(
                    in: text,
                    options: NSRegularExpression.MatchingOptions(),
                    range: NSMakeRange(0, text.count)
                ) { textCheckingResult, _, _ in
                    if let textCheckingResult,
                       isMention(text: text, position: textCheckingResult.range.location, textCount: text.count) {
                        let idStartIndex = text.index(text.startIndex, offsetBy: textCheckingResult.range.location + 2)
                        let idEndIndex = text.index(text.startIndex, offsetBy: textCheckingResult.range.location + 10)
                        tokens
                            .append(Token(
                                kind: .mention,
                                start: textCheckingResult.range.location,
                                end: textCheckingResult.range.location + textCheckingResult.range.length,
                                link: String("ThreemaId:" + text[idStartIndex..<idEndIndex])
                            ))
                    }
                }
            }
        }
        else {
            for (index, char) in utf16Text.enumerated() {
                if matchingMention {
                    if char == "]".utf16.first {
                        matchingMention = false
                        let idStartIndex = utf16Text.index(utf16Text.startIndex, offsetBy: index - 8)
                        let idEndIndex = utf16Text.index(utf16Text.startIndex, offsetBy: index)
                        tokens
                            .append(Token(
                                kind: .mention,
                                start: index - 10,
                                end: index + 1,
                                link: String("ThreemaId:" + text[idStartIndex..<idEndIndex])
                            ))
                    }
                }
                else {
                    // Detect URLs
                    if !matchingURL {
                        matchingURL = isURLStart(text: text, position: index, textCount: textCount)
                        if matchingURL, parseURL {
                            tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                        }
                    }
                    
                    if isMention(text: text, position: index, textCount: textCount), parseMention {
                        tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                        matchingMention = true
                    }
                    else if matchingURL {
                        // URLs have a limited set of boundary characters, therefore we need to
                        // treat them separately.
                        if isURLBoundary(text: text, position: index + 1, textCount: textCount) {
                            if parseURL {
                                let urlStartIndex = utf16Text.index(utf16Text.startIndex, offsetBy: index - tokenLength)
                                let urlEndIndex = utf16Text.index(utf16Text.startIndex, offsetBy: index + 1)
                                tokenLength = pushURLToken(
                                    tokenLength: &tokenLength,
                                    i: index,
                                    tokens: &tokens,
                                    url: String(text[urlStartIndex..<urlEndIndex])
                                )
                            }
                            else {
                                tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                            }
                            matchingURL = false
                        }
                        tokenLength += 1
                    }
                    else {
                        let prevIsBoundary = isBoundary(text: text, position: index - 1, textCount: textCount)
                        let nextIsBoundary = isBoundary(text: text, position: index + 1, textCount: textCount)
                        
                        if char == MarkupParser.MARKUP_CHAR_BOLD.utf16.first, prevIsBoundary || nextIsBoundary {
                            tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                            tokens.append(Token(kind: .asterisk, start: index, end: index + 1))
                        }
                        else if char == MarkupParser.MARKUP_CHAR_ITALIC.utf16.first, prevIsBoundary || nextIsBoundary {
                            tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                            tokens.append(Token(kind: .underscore, start: index, end: index + 1))
                        }
                        else if char == MarkupParser.MARKUP_CHAR_STRIKETHROUGH.utf16.first,
                                prevIsBoundary || nextIsBoundary {
                            tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                            tokens.append(Token(kind: .tilde, start: index, end: index + 1))
                        }
                        else if char == "\n".utf16.first {
                            tokenLength = pushTextToken(tokenLength: &tokenLength, i: index, tokens: &tokens)
                            tokens.append(Token(kind: .newLine, start: index, end: index + 1))
                        }
                        else {
                            tokenLength += 1
                        }
                    }
                }
            }
        }
        _ = pushTextToken(tokenLength: &tokenLength, i: textCount, tokens: &tokens, endOfText: true)
        
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
                    if attributedItem.textStart >= 0, attributedItem.textEnd <= attributedString.length {
                        if attributedItem.textStart != attributedItem.textEnd {
                            if let start = attributedItem.markerStart {
                                attributedString.addAttributes(
                                    MarkupParser.markupAttributes,
                                    range: NSRange(location: start, length: 1)
                                )
                            }
                            if var attributes = attributedItem.kind.attributes(font: font) {
                                switch attributedItem.kind {
                                case .asterisk, .underscore:
                                    // check is font already italic
                                    attributedString
                                        .enumerateAttributes(in: NSRange(
                                            location: attributedItem.textStart,
                                            length: attributedItem.textLength
                                        )) { attributes, range, _ in
                                            // check is attribute bold or italic
                                            if attributes.keys.contains(.font),
                                               let fontAttribute = attributes[.font] as? UIFont,
                                               fontAttribute.isBold() || fontAttribute.isItalic() {
                                                // to handle bold and italic
                                                doubleAttributes.append(range)
                                            }
                                        }
                                case .url:
                                    // add link to attributes
                                    attributes.updateValue(
                                        attributedItem.link ?? "",
                                        forKey: NSAttributedString.Key.link
                                    )
                                case .mention:
                                    // add link and contact to attributes
                                    let threemaID = attributedItem.link?.replacingOccurrences(
                                        of: "ThreemaId:",
                                        with: ""
                                    )
                                    if let contact = businessInjector.contactStore.contact(for: threemaID) {
                                        attributes.updateValue(
                                            MentionType.contact(contact),
                                            forKey: NSAttributedString.Key.contact
                                        )
                                    }
                                    else if threemaID == MarkupParser.MENTION_ALL {
                                        attributes.updateValue(
                                            MentionType.all,
                                            forKey: NSAttributedString.Key.contact
                                        )
                                    }
                                    else if threemaID == businessInjector.myIdentityStore.identity {
                                        attributes.updateValue(
                                            MentionType.me,
                                            forKey: NSAttributedString.Key.contact
                                        )
                                    }
                                    attributes.updateValue(
                                        attributedItem.link ?? "",
                                        forKey: NSAttributedString.Key.link
                                    )
                                default:
                                    break
                                }
                                
                                attributedString.addAttributes(
                                    attributes,
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
            case .url, .mention:
                attributedStack.append(AttributedItem(
                    kind: token.kind,
                    textStart: token.start,
                    textLength: token.end - token.start,
                    textEnd: token.end,
                    link: token.link
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
    public static let tokenType: NSAttributedString.Key = .init("tokenType")
    public static let contact: NSAttributedString.Key = .init("contact")
}
