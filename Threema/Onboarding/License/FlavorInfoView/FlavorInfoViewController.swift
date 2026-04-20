import Foundation
import SwiftUI

@objc final class FlavorInfoViewController: NSObject {
 
    @objc func viewController(dismiss: @escaping () -> Void) -> UIViewController {
        let flavorInfoView = FlavorInfoView(dismiss: dismiss)
        return UIHostingController(rootView: flavorInfoView)
    }
}
