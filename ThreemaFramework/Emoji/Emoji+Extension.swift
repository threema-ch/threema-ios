//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import CoreText
import Foundation
import UIKit

extension Emoji {
    public typealias SearchIndex = [EmojiVariant: [String]]
    
    // MARK: - Picker Search
    
    public static var searchIndex: SearchIndex? = {
        let languageCode: (any ExpressibleByStringLiteral)? =
            if #available(iOS 16, *) {
                Locale.current.language.languageCode
            }
            else {
                Locale.current.languageCode
            }
        
        guard let languageCode,
              "\(languageCode)" != "en" else {
            return searchIndex(for: "en")
        }
        
        // Fallback to English
        return searchIndex(for: languageCode)?
            .merging(searchIndex(for: "en") ?? [:]) {
                $0 + $1
            }
    }()
    
    private static func searchIndex(for languageCode: any ExpressibleByStringLiteral) -> SearchIndex? {
        guard
            let path = BundleUtil.path(
                forResource: "emojis.generated.localization.\(langcode(for: "\(languageCode)"))",
                ofType: "json"
            ) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let translations = try JSONDecoder().decode([String: [String]].self, from: data)
            
            var index = SearchIndex()
            translations.forEach { key, values in
                guard let variant = EmojiVariant(rawValue: key) else {
                    return
                }
                
                return index[variant] = values
            }
            
            return index
        }
        catch {
            DDLogError("Failed to load emoji search index: \(error)")
            return nil
        }
    }
    
    private static func langcode(for langcode: String) -> String {
        switch langcode {
        case "gsw", "rm":
            "de"
        case "de", "en", "es", "fr", "it", "ja", "ko", "nl", "pl", "pt", "ru", "uk", "zh":
            langcode
        default:
            "en"
        }
    }
    
    public var isAvailable: Bool {
        isEmojiAvailable(rawValue)
    }
    
    private func isEmojiAvailable(_ emoji: String) -> Bool {
        guard let font = UIFont(name: "AppleColorEmoji", size: 20) else {
            return false
        }
        let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        // Convert the emoji string to an array of UTF-16 code units
        let characters = Array(emoji.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)

        // Attempt to get glyphs for the characters in the emoji string
        let success = CTFontGetGlyphsForCharacters(ctFont, characters, &glyphs, characters.count)

        // If successful, the emoji is available
        return success
    }
    
    // MARK: - Legacy Mapping

    public enum LegacyMapping {
        case ack, dec
    }
    
    public func applyLegacyMapping() -> LegacyMapping? {
        let scalars = rawValue.unicodeScalars
        
        guard let first = scalars.first else {
            return nil
        }
        
        if first == Unicode.Scalar("👍") {
            return .ack
        }
        else if first == Unicode.Scalar("👎") {
            return .dec
        }
        
        return nil
    }

    /// A lookup dictionary to find emoji variants based on string representation. Reducing the need to parse the string
    /// multiple times.
    private static var emojiVariantsLookup: [String: EmojiVariant] = .init(
        Emoji.allVariants.flatMap { emoji, variants in
            variants.flatMap { skinTones, variantEmoji in
                skinTones.map { (variantEmoji, EmojiVariant(base: emoji, skintone: $0)) }
            } + [(emoji.rawValue, EmojiVariant(base: emoji, skintone: nil))]
        },
        uniquingKeysWith: { $1 }
    )
    
    public func variant(for skinToneOption: SkinTone?) -> String {
        if let skinToneOption {
            variants?[[skinToneOption]] ?? rawValue
        }
        else {
            rawValue
        }
    }
    
    /// Parses a string and returns an `EmojiVariant` if the string corresponds to a known emoji.
    /// - Parameter emoji: The string representation of the emoji.
    /// - Returns: An optional `EmojiVariant` if found, otherwise `nil`.
    public static func parse(_ emoji: String) -> EmojiVariant? {
        guard let entry = emojiVariantsLookup[emoji] else {
            if let baseEmoji = Emoji(rawValue: emoji) {
                return EmojiVariant(base: baseEmoji, skintone: nil)
            }
            else {
                return nil
            }
        }
        return entry
    }
    
    func data() -> Data {
        Data(rawValue.utf8)
    }
}

// MARK: - Emoji + Comparable

extension Emoji: Comparable {
    public static func < (lhs: Emoji, rhs: Emoji) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
