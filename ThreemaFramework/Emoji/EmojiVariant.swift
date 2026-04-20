import Foundation

/// Represents a combination of an `Emoji` and an optional `SkinTone`.
public struct EmojiVariant: Hashable, Identifiable, Equatable {
    
    public let base: Emoji
    public let skintone: Emoji.SkinTone?
    
    public var id: String
    public let rawValue: String
    public let hasSkinToneOptions: Bool
    
    var data: Data {
        Data(rawValue.utf8)
    }
    
    // MARK: - Lifecycle
    
    public init?(rawValue: String) {
        guard let emoji = Emoji.parse(rawValue) else {
            return nil
        }
        self = emoji
    }
    
    public init(base: Emoji, skintone: Emoji.SkinTone?) {
        self.base = base
        self.skintone = skintone
        
        self.hasSkinToneOptions = base.variants != nil
        self.rawValue = base.variant(for: skintone)
        self.id = rawValue + (skintone?.rawValue ?? "")
    }
}
