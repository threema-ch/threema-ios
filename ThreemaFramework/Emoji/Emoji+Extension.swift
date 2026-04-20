import CocoaLumberjackSwift
import CoreText
import Foundation
import UIKit

extension Emoji {
    public typealias SearchIndex = [EmojiVariant: [String]]
    
    // MARK: - Picker Search
    
    public static var searchIndex: SearchIndex? = {
        let languageCode: (any ExpressibleByStringLiteral)? = Locale.current.language.languageCode
        
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
                guard let variant = EmojiVariant(rawValue: key), variant.base.isAvailable else {
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
        // All pre iOS 17 are available due to our minimum target
        if version < 15.1 {
            true
        }
        else if version == 15.1, #available(iOS 17.4, *) {
            true
        }
        else if version == 16.0, #available(iOS 18.4, *) {
            true
        }
        else if version == 17.0, #available(iOS 26.4, *) {
            true
        }
        else {
            false
        }
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
