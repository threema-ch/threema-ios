import UIKit

/// Label with correct font and color for metadata text
final class MessageMetadataTextLabel: UILabel {

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLabel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabel()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    private func configureLabel() {
        numberOfLines = 0
        
        font = ChatViewConfiguration.MessageMetadata.font
        textColor = .secondaryLabel
        adjustsFontForContentSizeCategory = true
        
        lineBreakMode = .byWordWrapping
    }
}
