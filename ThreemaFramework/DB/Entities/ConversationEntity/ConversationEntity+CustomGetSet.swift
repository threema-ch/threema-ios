//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

extension ConversationEntity {
    
    public var conversationCategory: Category {
        Category(rawValue: Int(truncating: category))!
    }
    
    public var conversationVisibility: Visibility {
        Visibility(rawValue: Int(truncating: visibility))!
    }
    
    public func changeCategory(to category: Category) {
        let categoryKey = "category"
        willChangeValue(forKey: categoryKey)
        setPrimitiveValue(category.rawValue as NSNumber, forKey: categoryKey)
        didChangeValue(forKey: categoryKey)
    }
    
    public func changeVisibility(to visibility: Visibility) {
        let visibilityKey = "visibility"
        willChangeValue(forKey: visibilityKey)
        setPrimitiveValue(visibility.rawValue as NSNumber, forKey: visibilityKey)
        didChangeValue(forKey: visibilityKey)
    }
    
    @objc public func setTyping(to typing: Bool) {
        let typingKey = "typing"
        willChangeValue(forKey: typingKey)
        setPrimitiveValue(NSNumber(booleanLiteral: typing), forKey: typingKey)
        
        if typing {
            let lastTypingStartKey = "lastTypingStart"
            willChangeValue(forKey: lastTypingStartKey)
            setPrimitiveValue(Date.now, forKey: lastTypingStartKey)
            didChangeValue(forKey: lastTypingStartKey)
        }
        
        didChangeValue(forKey: typingKey)
    }
}
