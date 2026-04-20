import Foundation

extension UserSettings {
    public var recentEmojis: [String: Int] {
        set { AppGroup.userDefaults().set(newValue, forKey: "recentEmojis") }
        get { AppGroup.userDefaults().dictionary(forKey: "recentEmojis") as? [String: Int] ?? [:] }
    }
    
    public var emojiVariantPreference: [String: String] {
        set { AppGroup.userDefaults().set(newValue, forKey: "emojiVariantPreference") }
        get { AppGroup.userDefaults().dictionary(forKey: "emojiVariantPreference") as? [String: String] ?? [:] }
    }
    
    public func resetEmojiReactions() {
        AppGroup.userDefaults().removeObject(forKey: "recentEmojis")
        AppGroup.userDefaults().removeObject(forKey: "emojiVariantPreference")
    }
}

extension UserSettingsProtocol where Self == UserSettingsMock {
    public static var mock: Self { .init() }
}
