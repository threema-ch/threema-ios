//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import SwiftUI

protocol ProfilePictureGeneratorProtocol { }

/// Handles the generation of profile pictures
public class ProfilePictureGenerator: ProfilePictureGeneratorProtocol {
    
    // MARK: - Public properties
    
    public enum ProfilePictureType {
        case contact(letters: String)
        case distributionList
        case gateway
        case group
        case me
        case noteGroup
    }
    
    public static var unknownContactImage: UIImage = ProfilePictureGenerator.generateImage(
        for: .contact(letters: ""),
        color: UIColor.primary
    )
    
    public static var unknownDistributionListImage: UIImage = ProfilePictureGenerator.generateImage(
        for: .distributionList,
        color: UIColor.primary
    )
    
    public static var unknownGatewayImage: UIImage = ProfilePictureGenerator.generateImage(
        for: .gateway,
        color: UIColor.primary
    )
    
    public static var unknownGroupImage: UIImage = ProfilePictureGenerator.generateImage(
        for: .group,
        color: UIColor.primary
    )
    
    public static var unknownContactGroupCallsImage: UIImage = ProfilePictureGenerator.generateGroupCallImage(
        initials: "",
        color: .primary
    )
    
    // MARK: - Private properties

    private static let imageWidth = 512.0 / 3
    private static let iconHeight = 380.0 / 3
    
    // MARK: - Lifecycle

    public init() { }
    
    public static func generateImage(for type: ProfilePictureType, color: UIColor) -> UIImage {
        let foregroundColor = UIColor.IDColor.profilePictureForegroundColor(for: color)
        let backgroundColor = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        
        let image: UIImage? =
            switch type {
            case .contact, .me:
                UIImage(systemName: "person.fill")
            case .distributionList:
                UIImage(systemName: "megaphone.fill")
            case .gateway:
                UIImage(systemName: "asterisk")
            case .group:
                UIImage(systemName: "person.3.fill")
            case .noteGroup:
                UIImage(systemName: "note.text")
            }
        
        let imageSize = CGSize(width: imageWidth, height: imageWidth)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        
        let font =
            if let roundedFontDescriptor = UIFont.systemFont(ofSize: iconHeight / 2, weight: .bold)
                .fontDescriptor.withDesign(
                    UIFontDescriptor.SystemDesign.rounded
                ) {
                // A size of 0 does't override the existing size
                UIFont(descriptor: roundedFontDescriptor, size: 0)
            }
            else {
                UIFont.systemFont(ofSize: iconHeight / 2, weight: .bold)
            }
    
        let iconString: NSAttributedString
        
        if case let .contact(letters) = type, letters != "" {
            iconString = NSAttributedString(
                string: letters,
                attributes: [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.foregroundColor: foregroundColor,
                ]
            )
        }
        else {
            let icon = NSTextAttachment()
            icon.image = image!.withConfiguration(UIImage.SymbolConfiguration(font: font))
                .withTint(foregroundColor)
            iconString = NSAttributedString(attachment: icon)
        }
        
        let size = iconString.size()
        let iconOrigin = CGPoint(x: imageWidth * 0.5 - size.width * 0.5, y: imageWidth * 0.5 - size.height * 0.5)
       
        return renderer.image { context in
            UIColor.white.withAlphaComponent(0.1).setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
            backgroundColor.withAlphaComponent(0.25).setFill()
            context.fill(CGRect(origin: .zero, size: imageSize), blendMode: .normal)
            iconString.draw(in: CGRect(origin: iconOrigin, size: size))
        }
    }
    
    public static func generateGroupCallImage(initials: String, color: UIColor) -> UIImage {
        let foregroundColor = UIColor.white
        
        let image: UIImage? = UIImage(systemName: "person.fill")
        
        let imageSize = CGSize(width: imageWidth, height: imageWidth)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        
        let font =
            if let roundedFontDescriptor = UIFont.systemFont(ofSize: iconHeight / 2, weight: .bold)
                .fontDescriptor.withDesign(
                    UIFontDescriptor.SystemDesign.rounded
                ) {
                // A size of 0 does't override the existing size
                UIFont(descriptor: roundedFontDescriptor, size: 0)
            }
            else {
                UIFont.systemFont(ofSize: iconHeight / 2, weight: .bold)
            }
    
        let iconString: NSAttributedString
        
        if initials != "" {
            iconString = NSAttributedString(
                string: initials,
                attributes: [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.foregroundColor: foregroundColor,
                ]
            )
        }
        else {
            let icon = NSTextAttachment()
            icon.image = image!.withConfiguration(UIImage.SymbolConfiguration(font: font))
                .withTint(foregroundColor)
            iconString = NSAttributedString(attachment: icon)
        }
        
        let size = iconString.size()
        let iconOrigin = CGPoint(x: imageWidth * 0.5 - size.width * 0.5, y: imageWidth * 0.5 - size.height * 0.5)
       
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
            iconString.draw(in: CGRect(origin: iconOrigin, size: size))
        }
    }
    
    public static func addBackground(to image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
