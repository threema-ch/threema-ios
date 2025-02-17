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
