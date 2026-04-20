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
