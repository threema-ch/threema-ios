//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaMacros
import UIKit

public protocol MessageAccessibility: BaseMessageEntity {
    /// For private use only, use `customAccessibilityLabel` instead
    @available(*, deprecated, message: "For private use only, use `customAccessibilityLabel` instead")
    var privateCustomAccessibilityLabel: String { get }
    var customAccessibilityValue: String? { get }
    var customAccessibilityHint: String? { get }
    var customAccessibilityTrait: UIAccessibilityTraits { get }
    var accessibilityMessageTypeDescription: String { get }
}

extension MessageAccessibility {
    public var customAccessibilityLabel: String {
        // If deleted we return the default text
        guard deletedAt == nil else {
            return #localize("deleted_message")
        }
        
        return privateCustomAccessibilityLabel
    }
    
    public var customAccessibilityValue: String? {
        nil
    }

    public var customAccessibilityHint: String? {
        nil
    }

    public var customAccessibilityTrait: UIAccessibilityTraits {
        .none
    }
}
