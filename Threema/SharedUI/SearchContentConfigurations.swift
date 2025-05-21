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

import UIKit

/// Generate content configurations for search
enum SearchContentConfigurations {
    
    // MARK: - Header
    
    static let contentConfigurationSectionHeaderIdentifier = "contentConfigurationSectionHeaderIdentifier"
    
    static func contentConfigurationForSectionHeader(with localizedTitle: String) -> UIListContentConfiguration {
        var content = UIListContentConfiguration.prominentInsetGroupedHeader()
        
        content.text = localizedTitle
        
        // As we misuse the prominent inset group header style for a grouped table view we want the correct insets
        content.axesPreservingSuperviewLayoutMargins = .horizontal
                
        return content
    }
    
    // MARK: - Cells
    
    static let contentConfigurationTokenCellIdentifier = "contentConfigurationTokenCellIdentifier"
    static let contentConfigurationProgressCellIdentifier = "contentConfigurationProgressCellIdentifier"

    static func contentConfiguration(for token: GlobalSearchMessageToken) -> UIListContentConfiguration {
        var content = UIListContentConfiguration.cell()
        
        content.text = token.title
        content.image = token.icon
        
        let mediumScaleSymbolConfiguration = UIImage.SymbolConfiguration(scale: .medium)
        let mediumWeightSymbolConfiguration = UIImage.SymbolConfiguration(weight: .medium)
        content.imageProperties.preferredSymbolConfiguration = mediumScaleSymbolConfiguration.applying(
            mediumWeightSymbolConfiguration
        )
        
        return content
    }
}
