import UIKit

extension FileMessageEntity {
    @objc public var previewThumbnail: UIImage? {
        if let existingThumbnail = thumbnail?.uiImage() {
            return existingThumbnail
        }

        let defaultThumbnail = UTIConverter.getDefaultThumbnail(forMimeType: mimeType ?? "")
        return defaultThumbnail.withTintColor(.label)
    }
}
