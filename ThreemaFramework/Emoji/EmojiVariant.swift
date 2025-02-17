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
