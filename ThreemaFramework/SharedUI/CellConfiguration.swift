//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

/// Shared configuration between `ContactCell` & `GroupCell`
public struct CellConfiguration {
    
    public enum Size {
        case small
        case medium
    }
    
    private let size: Size
    
    // MARK: Configuration & helpers
    
    public let loadingAvatarImage = BundleUtil.imageNamed("Unknown")
    
    public var nameLabelFont: UIFont {
        switch size {
        case .small:
            return .preferredFont(forTextStyle: .headline)
        case .medium:
            let headlineFont = UIFont.preferredFont(forTextStyle: .headline)
            let labelFont = UIFont.systemFont(ofSize: headlineFont.pointSize + 1, weight: .semibold)
            return labelFont
        }
    }
    
    private let maxSmallAvatarSize: CGFloat = 40
    private let maxMediumAvatarSize: CGFloat = 48

    public var maxAvatarSize: CGFloat {
        if size == .medium {
            return maxMediumAvatarSize
        }
        
        return maxSmallAvatarSize
    }
    
    public let verticalSpacing: CGFloat = 4

    private let smallHorizontalSpacing: CGFloat = 10
    private let mediumHorizontalSpacing: CGFloat = 12
    
    public var horizontalSpacing: CGFloat {
        if size == .medium {
            return mediumHorizontalSpacing
        }
        
        return smallHorizontalSpacing
    }
    
    // MARK: - Lifecycle
    
    public init(size: Size) {
        self.size = size
    }
}
