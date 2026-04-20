import Foundation

final class MessageSymbolMetadataVibrancyView: UIView {
    
    /// Symbol to show before the text (leading side) if any
    var symbolName: String? {
        didSet {
            messageSymbolMetadataView.symbolName = symbolName
            blurEffectViewWorkaroundMessageSymbolMetadataView.symbolName = symbolName
        }
    }
    
    /// Metadata string to show if any
    var metadataString: String? {
        didSet {
            messageSymbolMetadataView.metadataString = metadataString
            blurEffectViewWorkaroundMessageSymbolMetadataView.metadataString = metadataString
        }
    }

    /// The view that should be affected by the vibrancy configuration
    var vibrancyAffectedView: MessageSymbolMetadataView {
        messageSymbolMetadataView
    }
    
    /// The view that should not be affected by the vibrancy configuration
    var vibrancyUnaffectedView: MessageSymbolMetadataView {
        blurEffectViewWorkaroundMessageSymbolMetadataView
    }
    
    private lazy var messageSymbolMetadataView = MessageSymbolMetadataView()
    private lazy var blurEffectViewWorkaroundMessageSymbolMetadataView = MessageSymbolMetadataView()
     
    // MARK: - Updates
    
    func updateColors() {
        
        if UIAccessibility.isReduceTransparencyEnabled {
            blurEffectViewWorkaroundMessageSymbolMetadataView.overrideColor = .secondaryLabel
        }
        else if UIAccessibility.isDarkerSystemColorsEnabled {
            blurEffectViewWorkaroundMessageSymbolMetadataView.overrideColor = .label
        }
        else {
            blurEffectViewWorkaroundMessageSymbolMetadataView.overrideColor = .clear
        }
        
        messageSymbolMetadataView.updateColors()
        blurEffectViewWorkaroundMessageSymbolMetadataView.updateColors()
    }
}
