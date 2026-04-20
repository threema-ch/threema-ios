import UIKit

/// Label with correct font for secondary text
final class MessageSecondaryTextLabel: RTLAligningLabel {
    
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
        
        font = ChatViewConfiguration.SecondaryText.font
        textColor = .secondaryLabel
        adjustsFontForContentSizeCategory = true
        
        lineBreakMode = .byWordWrapping
    }
}
