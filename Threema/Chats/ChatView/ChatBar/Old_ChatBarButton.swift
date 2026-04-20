import UIKit

// MARK: - Old_ChatBarButton.Configuration

extension Old_ChatBarButton {
    struct Configuration {
        var size: CGFloat = ChatBarConfiguration.defaultSize
        var scaledSize: CGFloat {
            UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        }
    }
}

@available(*, deprecated, message: "Use for pre iOS 26 only. For newer version use ChatBarButton instead.")
final class Old_ChatBarButton: ThemedCodeButton {
    
    private lazy var buttonConfiguration = Configuration()
    
    private var defaultColor: () -> UIColor
    
    private var sfSymbolName: String?
    
    init(
        sfSymbolName: String,
        accessibilityLabel: String,
        defaultColor: @escaping (() -> UIColor) = { .tintColor },
        customScalableSize: CGFloat? = nil,
        action: @escaping Action
    ) {
        
        self.defaultColor = defaultColor
        
        // Setting the actual frame size fixes an Auto Layout error that probably occurs when
        // there is no superview
        let initFrame = CGRect(
            x: 0, y: 0,
            width: 44,
            height: 44
        )
        
        super.init(frame: initFrame, action: action)
        
        if let customScalableSize {
            buttonConfiguration.size = customScalableSize
        }
        
        configureButton(with: sfSymbolName)
        updateColors()
        
        self.accessibilityLabel = accessibilityLabel
    }
    
    // MARK: - Configure
    
    public func updateButton(with sfSymbolName: String) {
        configureButton(with: sfSymbolName)
    }
    
    private func configureButton(
        with sfSymbolName: String
    ) {
        guard self.sfSymbolName != sfSymbolName else {
            return
        }
        
        self.sfSymbolName = sfSymbolName
        
        let image = UIImage(systemName: sfSymbolName)?.withRenderingMode(.alwaysTemplate)
        setImage(image, for: .normal)
        
        let configuration = UIImage.SymbolConfiguration(
            pointSize: buttonConfiguration.scaledSize,
            weight: .regular,
            scale: .large
        )
        setPreferredSymbolConfiguration(configuration, forImageIn: .normal)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        imageView?.tintColor = defaultColor()
    }
}
