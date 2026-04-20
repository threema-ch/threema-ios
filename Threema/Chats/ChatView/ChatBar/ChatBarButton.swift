import ThreemaMacros
import UIKit

// MARK: - ChatBarButton.Configuration

struct ChatBarButtonConfiguration {
    let baseConfiguration: UIButton.Configuration

    let systemImageName: String
    let tintColor: UIColor
    let accessibilityLabel: String
    
    var scaledSize: CGFloat {
        UIFontMetrics(forTextStyle: .body).scaledValue(for: ChatBarConfiguration.defaultSize)
    }
    
    let symbolWeight: UIImage.SymbolWeight
    let symbolScale: UIImage.SymbolScale
    
    init(
        baseConfiguration: UIButton.Configuration,
        systemImageName: String,
        tintColor: UIColor,
        accessibilityLabel: String,
        symbolWeight: UIImage.SymbolWeight = .regular,
        symbolScale: UIImage.SymbolScale = .default
    ) {
        self.baseConfiguration = baseConfiguration
        self.systemImageName = systemImageName
        self.tintColor = tintColor
        self.accessibilityLabel = accessibilityLabel
        self.symbolWeight = symbolWeight
        self.symbolScale = symbolScale
    }

    static var plusButton = {
        if #available(iOS 26.0, *) {
            return ChatBarButtonConfiguration(
                baseConfiguration: .glass(),
                systemImageName: "plus",
                tintColor: .label,
                accessibilityLabel: #localize("compose_bar_attachment_button_accessibility_label")
            )
        }
        else {
            assertionFailure("This button config should not be used before iOS 26.")
            return ChatBarButtonConfiguration(
                baseConfiguration: .plain(),
                systemImageName: "plus",
                tintColor: .label,
                accessibilityLabel: #localize("compose_bar_attachment_button_accessibility_label")
            )
        }
    }()
    
    static var sendButton = {
        if #available(iOS 26.0, *) {
            return ChatBarButtonConfiguration(
                baseConfiguration: .prominentGlass(),
                systemImageName: "arrow.up",
                tintColor: .labelInverted,
                accessibilityLabel: #localize("compose_bar_send_message_button_accessibility_label"),
                symbolWeight: .semibold
            )
        }
        else {
            assertionFailure("This button config should not be used before iOS 26.")
            return ChatBarButtonConfiguration(
                baseConfiguration: .borderedProminent(),
                systemImageName: "arrow.up",
                tintColor: .labelInverted,
                accessibilityLabel: #localize("compose_bar_send_message_button_accessibility_label")
            )
        }
    }()
    
    static var recordButton = ChatBarButtonConfiguration(
        baseConfiguration: .plain(),
        systemImageName: "mic",
        tintColor: .label,
        accessibilityLabel: #localize("compose_bar_record_button_accessibility_label")
    )
    
    static var cameraButton = ChatBarButtonConfiguration(
        baseConfiguration: .plain(),
        systemImageName: "camera",
        tintColor: .label,
        accessibilityLabel: #localize("compose_bar_camera_button_accessibility_label")
    )
    
    static var imagePickerButton = ChatBarButtonConfiguration(
        baseConfiguration: .plain(),
        systemImageName: "photo",
        tintColor: .label,
        accessibilityLabel: #localize("compose_bar_image_picker_button_accessibility_label")
    )
    
    static var closeEditButton: ChatBarButtonConfiguration = {
        let accessibilityLabel = #localize("accessibility_chatbar_close_edited_message_button_label")
        
        if #available(iOS 26.0, *) {
            return ChatBarButtonConfiguration(
                baseConfiguration: .plain(),
                systemImageName: "xmark",
                tintColor: .label,
                accessibilityLabel: accessibilityLabel
            )
        }
        else {
            return ChatBarButtonConfiguration(
                baseConfiguration: .plain(),
                systemImageName: "xmark.circle.fill",
                tintColor: Colors.backgroundButton,
                accessibilityLabel: accessibilityLabel,
                symbolScale: .large
            )
        }
    }()
    
    static var closeQuoteButton: ChatBarButtonConfiguration = {
        let accessibilityLabel = #localize("accessibility_chatbar_close_quote_button_label")
        
        if #available(iOS 26.0, *) {
            return ChatBarButtonConfiguration(
                baseConfiguration: .plain(),
                systemImageName: "xmark",
                tintColor: .label,
                accessibilityLabel: accessibilityLabel
            )
        }
        else {
            return ChatBarButtonConfiguration(
                baseConfiguration: .plain(),
                systemImageName: "xmark.circle.fill",
                tintColor: Colors.backgroundButton,
                accessibilityLabel: accessibilityLabel,
                symbolScale: .large
            )
        }
    }()
}

final class ChatBarButton: UIButton {
    
    private var buttonConfiguration: ChatBarButtonConfiguration
    
    init(
        for configuration: ChatBarButtonConfiguration,
        action: UIAction
    ) {
        self.buttonConfiguration = configuration
        
        super.init(frame: .zero)
        
        addAction(action, for: .touchUpInside)
        self.accessibilityLabel = configuration.accessibilityLabel

        configureButton()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateImage(imageName: String) {
        configuration?.image = UIImage(systemName: imageName)
    }
    
    // MARK: - Configuration
    
    private func configureButton() {
        var config = buttonConfiguration.baseConfiguration
        
        // Image
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: buttonConfiguration.scaledSize,
            weight: buttonConfiguration.symbolWeight,
            scale: buttonConfiguration.symbolScale
        )
        config.imagePlacement = .all // needed to center image

        config.image = UIImage(systemName: buttonConfiguration.systemImageName)
      
        config.baseForegroundColor = buttonConfiguration.tintColor
        
        configuration = config
    }
}
