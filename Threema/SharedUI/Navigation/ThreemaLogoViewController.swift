import SwiftUI

typealias ThreemaLogoViewController = UIHostingController<ThreemaLogoView>

enum ThreemaLogoViewControllerFactory {
    static var threemaLogoViewController: ThreemaLogoViewController {
        ThreemaLogoViewController(rootView: ThreemaLogoView())
    }
}
