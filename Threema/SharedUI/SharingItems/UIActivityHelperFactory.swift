import FileUtility
import ThreemaFramework
import UIKit

final class UIActivityHelperFactory: NSObject, Sendable {
    enum ItemSourceType {
        case zipFile(url: URL, subject: String)
        case messageActivity(MessageUIActivityItemSource.MessageShareContent)
    }

    enum ActivityType {
        case forwardURLs
    }

    static func makeItemSource(type: ItemSourceType) -> UIActivityItemSource {
        switch type {
        case let .zipFile(url: url, subject: subject):
            ZipFileUIActivityItemProvider(url: url, subject: subject)

        case let .messageActivity(content):
            MessageUIActivityItemSource(
                content: content,
                fileUtility: FileUtility.shared
            )
        }
    }

    static func makeActivity(type: ActivityType) -> UIActivity {
        switch type {
        case .forwardURLs:
            ForwardURLsUIActivity(bundleService: .live)
        }
    }
}

@available(swift, deprecated: 1.0, message: "Use makeActivity(type:) instead")
extension UIActivityHelperFactory {
    @objc static func makeForwardURLsUIActivity() -> ForwardURLsUIActivity {
        ForwardURLsUIActivity(bundleService: .live)
    }
}
