import Foundation
import ThreemaMacros

/// Preview of a message split into the parts that are formatted differently
public struct MessagePreviewDescription {
    /// Localized name of the message type, e.g. "Poll" or "Voice message (0:07)". `nil` if the message needs no type
    /// to be recognized.
    public let typeName: String?
    /// What this particular message is called, e.g. its text, a media caption, the title of a poll or a file name.
    /// Shown in quotes, `nil` if the message has nothing to name it by.
    public let quotedText: String?

    public init(typeName: String?, quotedText: String?) {
        self.typeName = typeName
        self.quotedText = quotedText
    }
}

public protocol PreviewableMessage: BaseMessageEntity {
    /// For private use only, use `previewText` instead
    @available(*, deprecated, message: "For private use only, use `previewText` instead")
    var privatePreviewText: String { get }
    /// For private use only, use `previewDescription` instead
    @available(*, deprecated, message: "For private use only, use `previewDescription` instead")
    var privatePreviewDescription: MessagePreviewDescription { get }
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
    
    /// Preview of this message split into its type name and what this message is called
    ///
    /// By default the whole preview is the quoted text, which is what a plain text message needs.
    public var previewDescription: MessagePreviewDescription {
        // A deleted message has no content left to quote
        guard deletedAt == nil else {
            return MessagePreviewDescription(typeName: previewText, quotedText: nil)
        }

        return privatePreviewDescription
    }

    public var privatePreviewDescription: MessagePreviewDescription {
        MessagePreviewDescription(typeName: nil, quotedText: privatePreviewText)
    }

    /// Preview of this message with the name of it in quotes, e.g. `Poll "Lunch place"` or `Image`
    ///
    /// Used where a message is referred to rather than shown, for example in the notification about a reaction to it.
    /// - Parameter configuration: Configuration the quoted text is trimmed and parsed with
    /// - Returns: Composed preview or `nil` if there is nothing to show
    public func quotedPreviewText(for configuration: PreviewableMessageConfiguration = .default) -> String? {
        let description = previewDescription

        var quotedText: String?
        if let text = description.quotedText {
            // Trim as Swift string to prevent emoji cropping, same as `previewAttributedText(for:settingsStore:)`
            let trimmedText = String(text.prefix(configuration.trimmingCount))
            let parsedText = MarkupParser().previewString(for: trimmedText, font: configuration.font)
            quotedText = "\"\(parsedText.string)\""
        }

        // Only one of both is shown if the other one is missing, e.g. `Image` or `"Probably a long msg"`
        guard let typeName = description.typeName else {
            return quotedText
        }
        
        guard let quotedText else {
            return typeName
        }

        return "\(typeName) \(quotedText)"
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
