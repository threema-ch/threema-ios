import SwiftUI

typealias ThreemaLogoViewController = UIHostingController<ThreemaLogoView>

enum ThreemaLogoViewControllerFactory {
    static let threemaLogoViewController =
        ThreemaLogoViewController(rootView: ThreemaLogoView())

    static func threemaLogoNavigationController() -> UINavigationController {
        ThemedNavigationController(rootViewController: threemaLogoViewController)
    }
}
