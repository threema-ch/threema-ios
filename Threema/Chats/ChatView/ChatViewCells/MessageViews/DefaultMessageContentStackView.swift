import UIKit

/// Message content stack with default insets
final class DefaultMessageContentStackView: UIStackView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureStackView()
    }
        
    required init(coder: NSCoder) {
        super.init(coder: coder)
        configureStackView()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    // The super implementation of this initializer cannot be overridden, thus we implement it ourselves.
    convenience init(arrangedSubviews views: [UIView]) {
        self.init()
        
        for view in views {
            addArrangedSubview(view)
        }
    }
    
    private func configureStackView() {
        axis = .vertical
        spacing = ChatViewConfiguration.Content.contentAndMetadataSpace
        isLayoutMarginsRelativeArrangement = true
    }
}
