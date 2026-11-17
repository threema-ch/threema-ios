import CocoaLumberjackSwift
import UIKit

/// View that draws a chat bubble in its bounds
final class ChatBubbleBackgroundView: UIView {
    
    /// Show a bubble arrow?
    enum ShowChatBubbleArrow {
        case leading
        case trailing
        case bubbles
        case none
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTraitRegistration()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Which bubble arrow should be shown?
    var showChatBubbleArrow: ShowChatBubbleArrow = .leading {
        didSet {
            guard oldValue != showChatBubbleArrow else {
                return
            }
            
            updatePaths(for: bounds)
        }
    }

    // MARK: Bubble shape

    private func setupTraitRegistration() {
        let traits: [UITrait] = [UITraitUserInterfaceStyle.self]
        registerForTraitChanges(traits) { [weak self] (_: Self, previous) in
            guard let self else {
                return
            }
            if previous.userInterfaceStyle != traitCollection.userInterfaceStyle {
                updateColors()
            }
        }
    }

    private lazy var backgroundLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        self.layer.addSublayer(shapeLayer)
        // You need to set the fillColor after you added it as a sublayer
        shapeLayer.fillColor = localBackgroundColor.cgColor
        return shapeLayer
    }()
    
    private(set) var backgroundPath = UIBezierPath() {
        didSet {
            guard animate else {
                backgroundLayer.path = backgroundPath.cgPath
                return
            }
                
            CATransaction.begin()
                
            let morph = CABasicAnimation(keyPath: "path")
                
            // If we are already animating, which will happen for example when adding the date and state view (where we
            // first get taller and then wider) we already have an animation in progress when starting the next one.
            // This gets the current position of our bubble and starts the next animation from it
            if let presentationLayer = backgroundLayer.presentation(),
               let currentPresentationLayerValue = presentationLayer.path {
                DDLogVerbose(
                    "Starting from existing animation with bounding box \(currentPresentationLayerValue.boundingBox)"
                )
                morph.fromValue = currentPresentationLayerValue
            }
            else {
                DDLogVerbose("Starting from current value \(String(describing: backgroundLayer.path?.boundingBox))")
                morph.fromValue = backgroundLayer.path
            }
                
            morph.toValue = backgroundPath.cgPath
                
            morph.duration = ChatViewConfiguration.ChatBubble.bubbleSizeChangeAnimationDurationInSeconds
            morph.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                
            // Set value that the path should have after the animation
            // Use this instead of `.fillMode`and `isRemovedOnCompletion` because those will keep the animation
            // "running"
            backgroundLayer.path = backgroundPath.cgPath

            // A fixed key replaces a running morph instead of stacking another one on the layer. Un-keyed animations
            // pile up when many layout passes run within one transaction (e.g. a split view collapse), and each
            // further `add` gets slower until the main thread hangs.
            backgroundLayer.add(morph, forKey: ChatBubbleBackgroundView.morphAnimationKey)
                
            // Commit our animation
            CATransaction.commit()
        }
    }

    /// Used to update the bubble frame for animations
    var bubbleFrame: CGRect? {
        didSet {
            guard let bubbleFrame else {
                return
            }
            
            updatePaths(for: bubbleFrame)
        }
    }
    
    // Indicates whether the next change to `bubbleFrame` should be animated or not
    var animate = false
    
    private static let morphAnimationKey = "path"

    private func updatePaths(for frame: CGRect) {
        // We always have a rounded rectangle background
        let path = ChatBubbleShape.roundedRect(for: frame, with: traitCollection)
        
        switch showChatBubbleArrow {
        case .leading:
            path.append(ChatBubbleShape.leadingArrow(for: frame))
        case .bubbles:
            for newPath in ChatBubbleShape.bubbles(for: frame) {
                path.append(newPath)
            }
        case .trailing:
            path.append(ChatBubbleShape.trailingArrow(for: frame).reversing())
        case .none:
            break
        }

        // Cells set `bubbleFrame` on every layout pass, mostly with an unchanged frame
        guard path.cgPath != backgroundPath.cgPath else {
            return
        }

        backgroundPath = path
    }
    
    // MARK: - Color
    
    private var localBackgroundColor: UIColor = .chatBubbleReceived
    
    // We override the default background color implementation to not set the actual background but the colors
    // of our custom layers.
    override var backgroundColor: UIColor? {
        set {
            guard let newValue else {
                return
            }
            
            // Did the color change?
            guard newValue != localBackgroundColor else {
                return
            }
            
            // Persist the current color
            localBackgroundColor = newValue
            updateColors()
            
            // Note: We don't set the super background color
        }
        
        get {
            localBackgroundColor
        }
    }
    
    private func updateColors() {
        backgroundLayer.fillColor = localBackgroundColor.cgColor
    }
}
