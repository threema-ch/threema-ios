//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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
    
    /// Configuration of the symbol placed in the attributed string
    public let symbolConfiguration: UIImage.SymbolConfiguration
    /// Font of the attributed string
    public let font: UIFont
    /// Tint color of the text and icon in the attributed string
    ///
    /// This is a closure so it uses the correct color depending on the theme as the `Colors` color are not dynamic yet
    public let tintColor: () -> UIColor
    /// Count of the characters the attributed string will be trimmed to
    public let trimmingCount: Int
    /// Bool deciding if the preview string should have the sender as prefix
    public let includeSender: Bool
    
    init(
        symbolConfiguration: UIImage.SymbolConfiguration,
        font: UIFont,
        tintColor: @escaping () -> UIColor,
        trimmingCount: Int,
        includeSender: Bool = false
    ) {
        self.symbolConfiguration = symbolConfiguration
        self.font = font
        self.tintColor = tintColor
        self.trimmingCount = trimmingCount
        self.includeSender = includeSender
    }
    
    // MARK: - Pre-defined type configurations

    public static let quote = PreviewableMessageConfiguration(
        symbolConfiguration: UIImage.SymbolConfiguration(
            textStyle: .caption1,
            scale: .small
        ),
        font: UIFont.preferredFont(forTextStyle: .caption1),
        tintColor: { Colors.textLight },
        trimmingCount: 200
    )
    
    public static let conversationCell = PreviewableMessageConfiguration(
        symbolConfiguration: UIImage.SymbolConfiguration(
            textStyle: .subheadline,
            scale: .small
        ),
        font: UIFont.preferredFont(forTextStyle: .subheadline),
        tintColor: { Colors.textLight },
        trimmingCount: 200,
        includeSender: true
    )
    
    public static let `default` = PreviewableMessageConfiguration(
        symbolConfiguration: UIImage.SymbolConfiguration(
            textStyle: .caption1,
            scale: .small
        ),
        font: UIFont.preferredFont(forTextStyle: .caption1),
        tintColor: { Colors.textLight },
        trimmingCount: 100
    )
}
