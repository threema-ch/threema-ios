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

/// Used to define configurations for each of the different places we use `PreviewableMessage`.
/// Preferably use pre-defined types
public struct PreviewableMessageConfiguration {
    
    public enum SenderVisibility {
        case none, basic, userSettings
    }
    
    /// Add leading symbol if needed
    public let showSymbol: Bool

    /// Configuration of the symbol placed in the attributed string
    public let symbolConfiguration: UIImage.SymbolConfiguration
    
    /// Font of the attributed string
    public let font: UIFont
    
    /// Tint color of the text and icon in the attributed string
    ///
    /// This is a closure so it uses the correct color depending on the theme as the `Colors` color are not dynamic yet
    public let tintColor: () -> UIColor
    
    /// Trim new lines
    public let trimNewLines: Bool
    
    /// Count of the characters the attributed string will be trimmed to
    public let trimmingCount: Int
    
    /// Deciding if and how the preview string should have the sender as prefix
    public let senderVisibility: SenderVisibility
    
    init(
        showSymbol: Bool,
        symbolConfiguration: UIImage.SymbolConfiguration,
        font: UIFont,
        tintColor: @escaping () -> UIColor,
        trimNewLines: Bool,
        trimmingCount: Int,
        senderVisibility: SenderVisibility
    ) {
        self.showSymbol = showSymbol
        self.symbolConfiguration = symbolConfiguration
        self.font = font
        self.tintColor = tintColor
        self.trimNewLines = trimNewLines
        self.trimmingCount = trimmingCount
        self.senderVisibility = senderVisibility
    }
    
    // MARK: - Pre-defined type configurations

    public static let quote = PreviewableMessageConfiguration(
        showSymbol: true,
        symbolConfiguration: UIImage.SymbolConfiguration(
            textStyle: .caption1,
            scale: .small
        ),
        font: UIFont.preferredFont(forTextStyle: .caption1),
        tintColor: { UIColor.secondaryLabel },
        trimNewLines: true,
        trimmingCount: 200,
        senderVisibility: .none
    )
    
    public static let conversationCell = PreviewableMessageConfiguration(
        showSymbol: true,
        symbolConfiguration: UIImage.SymbolConfiguration(
            textStyle: .subheadline,
            scale: .small
        ),
        font: UIFont.preferredFont(forTextStyle: .subheadline),
        tintColor: { UIColor.secondaryLabel },
        trimNewLines: true,
        trimmingCount: 200,
        senderVisibility: .basic
    )
    
    public static let searchCell = PreviewableMessageConfiguration(
        showSymbol: true,
        symbolConfiguration: UIImage.SymbolConfiguration(
            textStyle: .subheadline,
            scale: .small
        ),
        font: UIFont.preferredFont(forTextStyle: .subheadline),
        tintColor: { UIColor.secondaryLabel },
        trimNewLines: true,
        trimmingCount: 200,
        senderVisibility: .basic
    )
    
    public static let notificationBanner = PreviewableMessageConfiguration(
        showSymbol: true,
        symbolConfiguration: UIImage.SymbolConfiguration(
            textStyle: .subheadline,
            scale: .small
        ),
        font: UIFont.preferredFont(forTextStyle: .subheadline),
        tintColor: { UIColor.label },
        trimNewLines: true,
        trimmingCount: 200,
        senderVisibility: .basic
    )
    
    public static let pushNotification = PreviewableMessageConfiguration(
        showSymbol: false,
        symbolConfiguration: UIImage.SymbolConfiguration(
            textStyle: .subheadline,
            scale: .small
        ),
        font: UIFont.preferredFont(forTextStyle: .subheadline),
        tintColor: { UIColor.label },
        trimNewLines: false,
        trimmingCount: 200,
        senderVisibility: .userSettings
    )
    
    public static let `default` = PreviewableMessageConfiguration(
        showSymbol: true,
        symbolConfiguration: UIImage.SymbolConfiguration(
            textStyle: .caption1,
            scale: .small
        ),
        font: UIFont.preferredFont(forTextStyle: .caption1),
        tintColor: { UIColor.secondaryLabel },
        trimNewLines: true,
        trimmingCount: 100,
        senderVisibility: .none
    )
}
