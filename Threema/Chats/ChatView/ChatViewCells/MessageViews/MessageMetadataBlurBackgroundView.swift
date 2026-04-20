import UIKit

/// Blurry background view with rounded corners
final class MessageMetadataBlurBackgroundView: UIVisualEffectView {
        
    // MARK: - Views & constraints
    
    private lazy var sizeConstraint: NSLayoutConstraint = heightAnchor
        .constraint(greaterThanOrEqualToConstant: ChatViewConfiguration.MetadataBackground.cornerRadius * 2)
    
    // All the stuff to make it blurry and vibrant
    private let blurEffect = UIBlurEffect(style: .systemThinMaterial)
    private lazy var vibrantEffectView = UIVisualEffectView(
        effect: UIVibrancyEffect(blurEffect: blurEffect, style: .fill)
    )
    
    // MARK: - Lifecycle
    
    /// Create a new view
    ///
    /// - Parameters:
    ///   - rootView: (Container) view to display on top of the background with `UIVibrancyEffect`
    ///   - nonVibrantRootView: (Container) view to display on top of the background and `rootView` without
    /// `UIVibrancyEffect`
    init(
        rootView: UIView,
        nonVibrantRootView: UIView? = nil
    ) {
        super.init(effect: blurEffect)
        
        configureView(with: rootView, nonVibrantRootView: nonVibrantRootView)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateColors() {
        if UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled {
            backgroundColor = Colors.backgroundChatBar
        }
    }
    
    // MARK: - Configure
    
    private func configureView(with rootView: UIView, nonVibrantRootView: UIView?) {
        
        // Embed content into stack for easy vertical centering
        let rootStack = UIStackView(arrangedSubviews: [rootView])
        rootStack.alignment = .center
        
        // Layout
        vibrantEffectView.contentView.addSubview(rootStack)
        contentView.addSubview(vibrantEffectView)
        
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        vibrantEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        pinToContentView(rootStack)
        pinToContentView(vibrantEffectView)

        // Add `nonVibrantRootView` not affected by the default vibrancy effects (such as change to monochrome)
        // made by `UIVibrancyEffect`
        if let nonVibrantRootView {
            let nonVibrantRootStack = UIStackView(arrangedSubviews: [nonVibrantRootView])
            nonVibrantRootStack.alignment = .center
            
            // No extra container is needed. The stack view does all the needed things to align correctly.
            
            contentView.addSubview(nonVibrantRootStack)
            nonVibrantRootStack.translatesAutoresizingMaskIntoConstraints = false
            pinToContentView(nonVibrantRootStack)
        }
        
        sizeConstraint.isActive = true
        
        // Corner radius
        layer.cornerRadius = ChatViewConfiguration.MetadataBackground.cornerRadius
        clipsToBounds = true
        
        if UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled {
            backgroundColor = Colors.backgroundChatBar
        }
    }
    
    // All views have their constraints related to the `contentView`.
    private func pinToContentView(_ view: UIView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: ChatViewConfiguration.MetadataBackground.topAndBottomInset
            ),
            view.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: ChatViewConfiguration.MetadataBackground.leadingAndTrailingInset
            ),
            view.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -ChatViewConfiguration.MetadataBackground.topAndBottomInset
            ),
            view.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -ChatViewConfiguration.MetadataBackground.leadingAndTrailingInset
            ),
        ])
    }
}
