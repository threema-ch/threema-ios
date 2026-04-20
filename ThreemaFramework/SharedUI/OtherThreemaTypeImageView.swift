import UIKit

/// Shows icon for other Threema type
///
/// Use in combination with `Contact.showOtherThreemaTypeIcon`.
///
/// If you overlay it on the profile picture it should appear at the leading bottom and be 35 % of its size.
public final class OtherThreemaTypeImageView: UIImageView {
    
    public init() {
        super.init(image: ThreemaUtility.otherThreemaTypeIcon)
        
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureView() {
        widthAnchor.constraint(equalTo: heightAnchor).isActive = true
        
        accessibilityIgnoresInvertColors = true
        
        accessibilityLabel = ThreemaUtility.otherThreemaTypeAccessibilityLabel
    }
}
