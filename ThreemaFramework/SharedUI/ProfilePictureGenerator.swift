import Foundation
import SwiftUI

protocol ProfilePictureGeneratorProtocol { }

/// Handles the generation of profile pictures
public final class ProfilePictureGenerator: ProfilePictureGeneratorProtocol {
    
    // MARK: - Public properties
    
    public enum ProfilePictureType {
        case contact(letters: String)
        case distributionList
        case gateway
        case group
        case me
        case noteGroup
        case directoryContact
    }
    
    public static var unknownContactImage: UIImage = ProfilePictureGenerator.generateImage(
        for: .contact(letters: ""),
        color: .primary
    )
    
    public static var unknownDistributionListImage: UIImage = ProfilePictureGenerator.generateImage(
        for: .distributionList,
        color: .primary
    )
    
    public static var unknownGatewayImage: UIImage = ProfilePictureGenerator.generateImage(
        for: .gateway,
        color: .primary
    )
    
    public static var unknownGroupImage: UIImage = ProfilePictureGenerator.generateImage(
        for: .group,
        color: .primary
    )
    
    public static var unknownContactGroupCallsImage: UIImage = ProfilePictureGenerator.generateGroupCallImage(
        initials: "",
        color: .primary
    )
    
    public static var directoryContactImage: UIImage = ProfilePictureGenerator.generateImage(
        for: .directoryContact,
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

        let imageSize = CGSize(width: imageWidth, height: imageWidth)

        let systemImage: UIImage? =
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
            case .directoryContact:
                UIImage(systemName: "building.2.fill")
            }

        let fontSize = iconHeight / 2
        guard fontSize > 0 else {
            return makeFallbackImage(size: imageSize, color: backgroundColor)
        }

        let baseFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let font: UIFont =
            if let rounded = baseFont.fontDescriptor.withDesign(.rounded) {
                UIFont(descriptor: rounded, size: 0)
            }
            else {
                baseFont
            }

        let iconString: NSAttributedString

        if case let .contact(letters) = type, !letters.isEmpty {
            iconString = NSAttributedString(
                string: letters,
                attributes: [
                    .font: font,
                    .foregroundColor: foregroundColor,
                ]
            )
        }
        else {
            guard let resolvedImage = systemImage else {
                return makeFallbackImage(size: imageSize, color: backgroundColor)
            }

            let configuredImage = resolvedImage
                .withConfiguration(UIImage.SymbolConfiguration(font: font))
                .withTintColor(foregroundColor)

            let icon = NSTextAttachment()
            icon.image = configuredImage
            iconString = NSAttributedString(attachment: icon)
        }

        let size = iconString.size()
        guard size.width > 0, size.height > 0, size.width.isFinite, size.height.isFinite else {
            return makeFallbackImage(size: imageSize, color: backgroundColor)
        }

        let iconOrigin = CGPoint(
            x: imageWidth * 0.5 - size.width * 0.5,
            y: imageWidth * 0.5 - size.height * 0.5
        )

        let renderer = UIGraphicsImageRenderer(size: imageSize)
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

        let imageSize = CGSize(width: imageWidth, height: imageWidth)

        let fontSize = iconHeight / 2
        guard fontSize > 0 else {
            return makeFallbackImage(size: imageSize, color: color)
        }

        let baseFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let font: UIFont =
            if let rounded = baseFont.fontDescriptor.withDesign(.rounded) {
                UIFont(descriptor: rounded, size: 0)
            }
            else {
                baseFont
            }

        let iconString: NSAttributedString

        if !initials.isEmpty {
            iconString = NSAttributedString(
                string: initials,
                attributes: [
                    .font: font,
                    .foregroundColor: foregroundColor,
                ]
            )
        }
        else {
            guard let systemImage = UIImage(systemName: "person.fill") else {
                return makeFallbackImage(size: imageSize, color: color)
            }

            let configuredImage = systemImage
                .withConfiguration(UIImage.SymbolConfiguration(font: font))
                .withTintColor(foregroundColor)

            let icon = NSTextAttachment()
            icon.image = configuredImage
            iconString = NSAttributedString(attachment: icon)
        }

        let size = iconString.size()
        guard size.width > 0, size.height > 0, size.width.isFinite, size.height.isFinite else {
            return makeFallbackImage(size: imageSize, color: color)
        }

        let iconOrigin = CGPoint(
            x: imageWidth * 0.5 - size.width * 0.5,
            y: imageWidth * 0.5 - size.height * 0.5
        )

        let renderer = UIGraphicsImageRenderer(size: imageSize)
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

    // MARK: Helpers

    private static func makeFallbackImage(size: CGSize, color: UIColor) -> UIImage {
        let fallbackRenderer = UIGraphicsImageRenderer(size: size)
        return fallbackRenderer.image { ctx in
            color.withAlphaComponent(0.25).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
