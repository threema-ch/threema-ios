//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ThreemaMacros

public protocol PreviewableMessage: BaseMessage {
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
    public func previewAttributedText(for configuration: PreviewableMessageConfiguration = .default)
        -> NSAttributedString {
        // Trim text as Swift string to prevent emoji cropping
        var trimmedString = String(previewText.prefix(configuration.trimmingCount))
        
        // To make the deleted text cursive, we insert "_"
        if deletedAt != nil {
            trimmedString = "_\(trimmedString)_"
        }
            
        let parsedString = MarkupParser().previewString(for: trimmedString, font: configuration.font)
        let configuredAttributedText = NSMutableAttributedString(attributedString: parsedString)
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
        
        configuredAttributedText.removeAttribute(
            NSAttributedString.Key.link,
            range: NSRange(location: 0, length: configuredAttributedText.length)
        )
        configuredAttributedText.addAttributes(
            [NSAttributedString.Key.foregroundColor: configuration.tintColor()],
            range: NSRange(location: 0, length: configuredAttributedText.length)
        )
        
        // If the message was remotely deleted, or no symbol was found, we return the text without one
        if deletedAt == nil, let image = previewSymbol {
            // Create string containing icon
            let icon = NSTextAttachment()
            var tintColor: UIColor? = previewSymbolTintColor
            
            if previewSymbolTintColor == nil {
                tintColor = configuration.tintColor()
            }
            
            icon.image = image.withConfiguration(configuration.symbolConfiguration)
                .withTint(tintColor)
            
            let iconString = NSAttributedString(attachment: icon)
            
            // Add icon and safe empty space to text
            let attributedSpace = NSAttributedString(string: " ")
            configuredAttributedText.insert(attributedSpace, at: 0)
            configuredAttributedText.insert(iconString, at: 0)
        }
        
        // Add the sender name if specified in PreviewableMessageConfiguration
        let shouldShowName = configuration.includeSender &&
            (conversation?.isGroup ?? false) &&
            !(self is SystemMessageEntity) // TODO: We might need to update this for group calls
        
        if shouldShowName {
            let attributedName =
                if let name = sender?.displayName {
                    NSAttributedString(string: "\(name): ")
                }
                else {
                    NSAttributedString(string: "\(#localize("me")): ")
                }
            configuredAttributedText.insert(attributedName, at: 0)
        }
        
        return configuredAttributedText
    }
}
