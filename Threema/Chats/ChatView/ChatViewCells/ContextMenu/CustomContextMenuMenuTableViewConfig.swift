//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

public struct CustomContextMenuMenuTableViewConfig {
    // Table
    let sectionSpacingHeight: CGFloat
    let sectionBackgroundColorDark: UIColor
    let sectionBackgroundColorLight: UIColor
    let tableViewBackgroundColorDark: UIColor
    let tableViewBackgroundColorLight: UIColor
    let tableViewHighlightedColor: UIColor
    let tableViewSeparatorColor: UIColor
    let tableViewWidth: CGFloat
    let tableViewCornerRadius: CGFloat
    
    // Item
    let itemLeadingTrailingInset: CGFloat
    let defaultItemTopBottomInset: CGFloat
    let defaultItemTopTweak: CGFloat
    let defaultItemSpacing: CGFloat
    let defaultImageCenterInset: CGFloat
    let inlineItemTopBottomInset: CGFloat
    let inlineItemCornerRadius: CGFloat
    let inlineItemSpacing: CGFloat
    let inlineItemInset: CGFloat
    
    // Default initializer created by compiler is enough
    
    // This tries to match the appearance on iOS 18.2
    static let defaultConfig = CustomContextMenuMenuTableViewConfig(
        sectionSpacingHeight: 8,
        sectionBackgroundColorDark: .systemBackground.withAlphaComponent(0.7),
        sectionBackgroundColorLight: .black.withAlphaComponent(0.4),
        tableViewBackgroundColorDark: .secondarySystemBackground.withAlphaComponent(0.7),
        tableViewBackgroundColorLight: .systemBackground.withAlphaComponent(0.5),
        tableViewHighlightedColor: .gray.withAlphaComponent(0.2),
        tableViewSeparatorColor: .quaternaryLabel,
        tableViewWidth: UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory ? 300 : 250,
        tableViewCornerRadius: 14,
        itemLeadingTrailingInset: 16,
        defaultItemTopBottomInset: 12,
        defaultItemTopTweak: -0.66,
        defaultItemSpacing: 4,
        defaultImageCenterInset: 12,
        inlineItemTopBottomInset: 8.5,
        inlineItemCornerRadius: 8,
        inlineItemSpacing: 16,
        inlineItemInset: 8
    )
}
