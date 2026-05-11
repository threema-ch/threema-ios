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

    // Immutable constants – `let` prevents accidental external mutation.
    public static let unknownContactImage: UIImage = generateImage(
        for: .contact(letters: ""),
        color: .primary
    )

    public static let unknownDistributionListImage: UIImage = generateImage(
        for: .distributionList,
        color: .primary
    )

    public static let unknownGatewayImage: UIImage = generateImage(
        for: .gateway,
        color: .primary
    )

    public static let unknownGroupImage: UIImage = generateImage(
        for: .group,
        color: .primary
    )

    public static let unknownContactGroupCallsImage: UIImage = generateGroupCallImage(
        initials: "",
        color: .primary
    )

    public static let directoryContactImage: UIImage = generateImage(
        for: .directoryContact,
        color: .primary
    )

    // MARK: - Private constants

    private static let imageWidth = 512.0 / 3
    private static let iconHeight = 380.0 / 3

    // Pre-computed from the constants above – no need to recompute on every call.
    private static let imageSize = CGSize(width: imageWidth, height: imageWidth)
    private static let fontSize = iconHeight / 2

    // Always the same value; allocate once.
    private static let lightTraitCollection = UITraitCollection(userInterfaceStyle: .light)

    // Font is determined solely by `fontSize` (a constant), so compute it once.
    private static let font: UIFont = {
        let base = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: 0)
        }
        return base
    }()

    // Symbol configuration derived from the constant font – compute once.
    private static let symbolConfiguration = UIImage.SymbolConfiguration(font: font)

    // Force standard (8-bit) colour range for all rendered images.
    // The default `.automatic` format uses 16-bit/channel (half-float) on P3 displays,
    // doubling the memory footprint per image with no visible benefit for icons.
    private static let rendererFormat: UIGraphicsImageRendererFormat = {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .standard
        return format
    }()

    // MARK: - Lifecycle

    public init() { }

    // MARK: - Image generation

    public static func generateImage(for type: ProfilePictureType, color: UIColor) -> UIImage {
        autoreleasepool {
            let foregroundColor = UIColor.IDColor.profilePictureForegroundColor(for: color)
            let backgroundColor = color.resolvedColor(with: lightTraitCollection)

            guard fontSize > 0 else {
                return makeFallbackImage(size: imageSize, color: backgroundColor)
            }

            let iconString: NSAttributedString

            if case let .contact(letters) = type, !letters.isEmpty {
                iconString = NSAttributedString(
                    string: letters,
                    attributes: [.font: font, .foregroundColor: foregroundColor]
                )
            }
            else {
                let symbolName =
                    switch type {
                    case .contact, .me: "person.fill"
                    case .distributionList: "megaphone.fill"
                    case .gateway: "asterisk"
                    case .group: "person.3.fill"
                    case .noteGroup: "note.text"
                    case .directoryContact: "building.2.fill"
                    }

                guard let symbol = UIImage(systemName: symbolName) else {
                    return makeFallbackImage(size: imageSize, color: backgroundColor)
                }

                let configured = symbol
                    .withConfiguration(symbolConfiguration)
                    .withTintColor(foregroundColor)

                let attachment = NSTextAttachment()
                attachment.image = configured
                iconString = NSAttributedString(attachment: attachment)
            }

            let iconSize = iconString.size()
            guard iconSize.width > 0, iconSize.height > 0,
                  iconSize.width.isFinite, iconSize.height.isFinite else {
                return makeFallbackImage(size: imageSize, color: backgroundColor)
            }

            let iconOrigin = CGPoint(
                x: imageWidth * 0.5 - iconSize.width * 0.5,
                y: imageWidth * 0.5 - iconSize.height * 0.5
            )

            let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
            return renderer.image { context in
                UIColor.white.withAlphaComponent(0.1).setFill()
                context.fill(CGRect(origin: .zero, size: imageSize))
                backgroundColor.withAlphaComponent(0.25).setFill()
                context.fill(CGRect(origin: .zero, size: imageSize), blendMode: .normal)
                iconString.draw(in: CGRect(origin: iconOrigin, size: iconSize))
            }
        }
    }

    public static func generateGroupCallImage(initials: String, color: UIColor) -> UIImage {
        autoreleasepool {
            guard fontSize > 0 else {
                return makeFallbackImage(size: imageSize, color: color)
            }

            let iconString: NSAttributedString

            if !initials.isEmpty {
                iconString = NSAttributedString(
                    string: initials,
                    attributes: [.font: font, .foregroundColor: UIColor.white]
                )
            }
            else {
                guard let symbol = UIImage(systemName: "person.fill") else {
                    return makeFallbackImage(size: imageSize, color: color)
                }

                let configured = symbol
                    .withConfiguration(symbolConfiguration)
                    .withTintColor(.white)

                let attachment = NSTextAttachment()
                attachment.image = configured
                iconString = NSAttributedString(attachment: attachment)
            }

            let iconSize = iconString.size()
            guard iconSize.width > 0, iconSize.height > 0,
                  iconSize.width.isFinite, iconSize.height.isFinite else {
                return makeFallbackImage(size: imageSize, color: color)
            }

            let iconOrigin = CGPoint(
                x: imageWidth * 0.5 - iconSize.width * 0.5,
                y: imageWidth * 0.5 - iconSize.height * 0.5
            )

            let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
            return renderer.image { context in
                color.setFill()
                context.fill(CGRect(origin: .zero, size: imageSize))
                iconString.draw(in: CGRect(origin: iconOrigin, size: iconSize))
            }
        }
    }

    public static func addBackground(to image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Helpers

    private static func makeFallbackImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)
        return renderer.image { ctx in
            color.withAlphaComponent(0.25).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
