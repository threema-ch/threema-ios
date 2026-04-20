import ThreemaMacros
import UIKit

/// Typical circle with x mark icon, but the x mark is not transparent
public final class OpaqueDeleteButton: ThemedCodeButton {

    /// Background to make x opaque
    private lazy var xMarkBackgroundView: UIView = {
        let view = UIView()
        // Needed such that button gets UIEvents
        view.isUserInteractionEnabled = false
        view.backgroundColor = .secondarySystemGroupedBackground
        return view
    }()
    
    override public func configureButton() {
        super.configureButton()

        // Add and layout subviews

        addSubview(xMarkBackgroundView)
        setImage(
            UIImage(systemName: "xmark.circle.fill")?.applying(symbolWeight: .heavy, symbolScale: .large),
            for: .normal
        )
    
        xMarkBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        // Inset x mark background to make it not appear outside of the circle
        let xMarkBackgroundInset: CGFloat = 8
        
        NSLayoutConstraint.activate([
            xMarkBackgroundView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: xMarkBackgroundInset
            ),
            xMarkBackgroundView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: xMarkBackgroundInset
            ),
            xMarkBackgroundView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -xMarkBackgroundInset
            ),
            xMarkBackgroundView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -xMarkBackgroundInset
            ),
        ])
        
        accessibilityLabel = #localize("delete")
        
        tintColor = .systemGray
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        guard let imageView else {
            return
        }
        
        insertSubview(xMarkBackgroundView, belowSubview: imageView)
    }
}
