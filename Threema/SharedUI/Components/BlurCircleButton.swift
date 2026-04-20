import UIKit

/// Circle button with an vibrant icon in the center and a blurry background
///
/// Use as-is and provide all configuration during initialization. Using `UIButton` methods might lead to unexpected
/// side-effects.
final class BlurCircleButton: ThemedCodeButton {

    private let blurCircleView: BlurCircleView
    
    override var isHighlighted: Bool {
        didSet {
            if oldValue == false, isHighlighted {
                blurCircleView.highlight(true, highlightingAlpha: 0.5)
            }
            else if oldValue == true, !isHighlighted {
                blurCircleView.highlight(false)
            }
        }
    }
    
    // MARK: - Lifecycle
    
    /// Create a new button
    ///
    /// - Parameters:
    ///   - sfSymbolName: Name of SF Symbol to show
    ///   - accessibilityLabel: Description of the button action for accessibility users
    ///   - action: Action called when the button is tapped
    init(
        sfSymbolName: String,
        accessibilityLabel: String,
        configuration: BlurCircleView.BlurCircleViewConfigurationType = .default,
        action: @escaping Action
    ) {
        self.blurCircleView = BlurCircleView(sfSymbolName: sfSymbolName, configuration: configuration)
        
        super.init(frame: .zero, action: action)
                
        self.accessibilityLabel = accessibilityLabel
    }
    
    // MARK: - Configure
    
    override func configureButton() {
        super.configureButton()
        
        // Needed to get UIEvents to button
        blurCircleView.isUserInteractionEnabled = false
        
        addSubview(blurCircleView)
        blurCircleView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            blurCircleView.topAnchor.constraint(equalTo: topAnchor),
            blurCircleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurCircleView.bottomAnchor.constraint(equalTo: bottomAnchor),
            blurCircleView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    
    // MARK: - Update
    
    func updateSymbol(to sfSymbolName: String) {
        blurCircleView.updateSymbol(to: sfSymbolName)
    }
}
