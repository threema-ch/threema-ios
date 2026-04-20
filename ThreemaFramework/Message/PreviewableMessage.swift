import Foundation
import ThreemaMacros

public protocol PreviewableMessage: BaseMessageEntity {
    /// For private use only, use `previewText` instead
    @available(*, deprecated, message: "For private use only, use `previewText` instead")
    var privatePreviewText: String { get }
    /// System name or asset name of a symbol
    var previewSymbolName: String? { get }
    /// Configuration to be applied to symbol
    var previewSymbolTintColor: UIColor? { get }
    /// Optional tuple containing a optional thumbnail and the info if the entity is playable
    var mediaPreview: (thumbnail: UIImage, isPlayable: Bool)? { get }
}

extension PreviewableMessage {
    
    /// The raw text used in previews, use `previewAttributedText(for:)` directly
    public var previewText: String {
        // If deleted we return the default text
        guard deletedAt == nil else {
            return #localize("deleted_message")
        }
        
        return privatePreviewText
    }
    
    public var previewSymbolName: String? {
        nil
    }
    
    public var previewSymbolTintColor: UIColor? {
        nil
    }
    
    public var mediaPreview: (thumbnail: UIImage, isPlayable: Bool)? {
        nil
    }
    
    /// Returns the symbol with the name specified in `previewSymbolName`
    /// - Returns: Optional UIImage if the`previewSymbolName` could be resolved
    public var previewSymbol: UIImage? {
        guard let previewSymbolName else {
            return nil
        }
        
        if let image = UIImage(systemName: previewSymbolName) {
            return image
        }
        else if let image = UIImage(named: previewSymbolName) {
            return image
        }
        
        return nil
    }
    
    /// Creates an attributed string with a leading icon to be used in defined place
    /// - Parameter type: Place where attributed string will be used
    /// - Returns: NSAttributedString containing the preview text and optionally a Symbol
    public func previewAttributedText(
        for configuration: PreviewableMessageConfiguration = .default,
        settingsStore: SettingsStoreProtocol
    ) -> NSAttributedString {
        
        // Trim text as Swift string to prevent emoji cropping
        var trimmedString = String(previewText.prefix(configuration.trimmingCount))
        
        // To make the deleted text cursive, we insert "_"
        if deletedAt != nil {
            trimmedString = "_\(trimmedString)_"
        }
        
        let parsedString = MarkupParser().previewString(for: trimmedString, font: configuration.font)
        let configuredAttributedText = NSMutableAttributedString(attributedString: parsedString)
        
        if configuration.trimNewLines {
            configuredAttributedText.mutableString.replaceOccurrences(
                of: " \n",
                with: "\n",
                options: [],
                range: NSMakeRange(0, configuredAttributedText.length)
            )
            configuredAttributedText.mutableString.replaceOccurrences(
                of: "\n ",
                with: "\n",
                options: [],
                range: NSMakeRange(0, configuredAttributedText.length)
            )
            configuredAttributedText.mutableString.replaceOccurrences(
                of: "\n",
                with: " ",
                options: [],
                range: NSMakeRange(0, configuredAttributedText.length)
            )
        }
        
        configuredAttributedText.removeAttribute(
            NSAttributedString.Key.link,
            range: NSRange(location: 0, length: configuredAttributedText.length)
        )
        configuredAttributedText.addAttributes(
            [NSAttributedString.Key.foregroundColor: configuration.tintColor()],
            range: NSRange(location: 0, length: configuredAttributedText.length)
        )
        
        // If the message was remotely deleted, or no symbol was found, we return the text without one
        if configuration.showSymbol, deletedAt == nil, let image = previewSymbol {
            // Create string containing icon
            let icon = NSTextAttachment()
            let tintColor: UIColor = previewSymbolTintColor ?? configuration.tintColor()
                        
            icon.image = image.withConfiguration(configuration.symbolConfiguration)
                .withTintColor(tintColor)
            
            let iconString = NSAttributedString(attachment: icon)
            
            // Add icon and safe empty space to text
            let attributedSpace = NSAttributedString(string: " ")
            configuredAttributedText.insert(attributedSpace, at: 0)
            configuredAttributedText.insert(iconString, at: 0)
        }
        
        // Add the sender name if specified in PreviewableMessageConfiguration
        if let prefix = senderPrefix(
            visibility: configuration.senderVisibility,
            conversation: conversation,
            settingsStore: settingsStore
        ) {
            configuredAttributedText.insert(prefix, at: 0)
        }
        
        return configuredAttributedText
    }
    
    private func senderPrefix(
        visibility: PreviewableMessageConfiguration.SenderVisibility,
        conversation: ConversationEntity,
        settingsStore: SettingsStoreProtocol
    ) -> NSAttributedString? {
        
        // No prefix needed for non-group chats or system messages
        guard conversation.isGroup, !(self is SystemMessageEntity) else {
            return nil
        }
        
        switch visibility {
        case .none:
            return nil
        case .basic:
            return if let name = sender?.displayName {
                NSAttributedString(string: "\(name): ")
            }
            else {
                NSAttributedString(string: "\(#localize("me")): ")
            }
        case .userSettings:
            let notificationType = settingsStore.notificationType
            
            switch notificationType {
            case .restrictive:
                return NSAttributedString(
                    string: "\(sender?.publicNickname ?? sender?.identity ?? #localize("unknown")): "
                )
                
            case .balanced:
                return NSAttributedString(string: "\(sender?.displayName ?? #localize("unknown")): ")
                
            case .complete:
                return nil
            }
        }
    }
}
