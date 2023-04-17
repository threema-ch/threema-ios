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

public protocol PreviewableMessage: BaseMessage {
    
    /// The raw text used in previews, use `previewAttributedText(for:)` directly
    var previewText: String { get }
    /// System name or asset name of a symbol
    var previewSymbolName: String? { get }
    /// Configuration to be applied to symbol
    var previewSymbolTintColor: UIColor? { get }
    /// Optional tuple containing a optional thumbnail and the info if the entity is playable
    var mediaPreview: (thumbnail: UIImage, isPlayable: Bool)? { get }
}

public extension PreviewableMessage {
    
    var previewSymbolName: String? {
        nil
    }
    
    var previewSymbolTintColor: UIColor? {
        nil
    }
    
    var mediaPreview: (thumbnail: UIImage, isPlayable: Bool)? {
        nil
    }
    
    /// Returns the symbol with the name specified in `previewSymbolName`
    /// - Returns: Optional UIImage if the`previewSymbolName` could be resolved
    var previewSymbol: UIImage? {
        guard let previewSymbolName = previewSymbolName else {
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
    func previewAttributedText(for configuration: PreviewableMessageConfiguration = .default) -> NSAttributedString {
        // Trim text as Swift string to prevent emoji cropping
        let trimmedString = String(previewText.prefix(configuration.trimmingCount))
        
        // To catch all new lines, we need to remove them in a chain
        let noNewLinesString = trimmedString
            .replacingOccurrences(of: " \n", with: "\n")
            .replacingOccurrences(of: "\n ", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
        
        let parsedString = MarkupParser().previewString(for: noNewLinesString)
        
        let configurationAttributes = [
            NSAttributedString.Key.foregroundColor: configuration.tintColor(),
            NSAttributedString.Key.font: configuration.font,
        ]
        
        let configuredAttributedText = NSMutableAttributedString(
            string: parsedString,
            attributes: configurationAttributes
        )
                
        // If no symbol was found, we return the text without one
        if let image = previewSymbol {
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
            (conversation?.isGroup() ?? false) &&
            !(self is SystemMessage) // TODO: We might need to update this for group calls

        if shouldShowName {
            let attributedName: NSAttributedString
            
            if let name = sender?.displayName {
                attributedName = NSAttributedString(string: "\(name): ")
            }
            else {
                attributedName = NSAttributedString(string: "\(BundleUtil.localizedString(forKey: "me")): ")
            }
            configuredAttributedText.insert(attributedName, at: 0)
        }
        
        return configuredAttributedText
    }
}