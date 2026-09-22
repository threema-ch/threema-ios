import UIKit
import UniformTypeIdentifiers

extension UIPasteboard {

    enum SensitiveContent {

        /// There is no legitimate reason for it to appear on another device, so it stays here.
        case secretThisDeviceOnly

        /// Handing it over via the Universal Clipboard is the whole point of copying it.
        case secretAllDevices

        /// Content of a message, like its text or its media
        case messageContent

        /// How long the content stays on the pasteboard
        fileprivate var expirationInterval: TimeInterval {
            switch self {
            case .secretThisDeviceOnly, .secretAllDevices:
                2 * 60
            case .messageContent:
                10 * 60
            }
        }

        fileprivate var isLocalOnly: Bool {
            switch self {
            case .secretThisDeviceOnly:
                true
            case .secretAllDevices, .messageContent:
                false
            }
        }
    }

    /// Copies a string as sensitive content
    /// - Parameters:
    ///   - string: String to copy
    ///   - sensitiveContent: Kind of content, defines how long it stays on the pasteboard and whether it may leave
    ///                       this device
    func set(string: String, sensitiveContent: SensitiveContent) {
        set(items: [[UTType.utf8PlainText.identifier: string]], sensitiveContent: sensitiveContent)
    }

    /// Copies an image as sensitive content
    ///
    /// In contrast to `image`, the image is only put on the pasteboard as PNG.
    ///
    /// - Parameters:
    ///   - image: Image to copy
    ///   - sensitiveContent: Kind of content, defines how long it stays on the pasteboard and whether it may leave
    ///                       this device
    func set(image: UIImage, sensitiveContent: SensitiveContent) {
        guard let data = image.pngData() else {
            return
        }

        set(data: data, forPasteboardType: UTType.png.identifier, sensitiveContent: sensitiveContent)
    }

    /// Copies data as sensitive content
    /// - Parameters:
    ///   - data: Data to copy
    ///   - forPasteboardType: Uniform type identifier of the data
    ///   - sensitiveContent: Kind of content, defines how long it stays on the pasteboard and whether it may leave
    ///                       this device
    func set(data: Data, forPasteboardType type: String, sensitiveContent: SensitiveContent) {
        set(items: [[type: data]], sensitiveContent: sensitiveContent)
    }

    private func set(items: [[String: Any]], sensitiveContent: SensitiveContent) {
        setItems(items, options: [
            .localOnly: sensitiveContent.isLocalOnly,
            .expirationDate: Date(timeIntervalSinceNow: sensitiveContent.expirationInterval),
        ])
    }
}
