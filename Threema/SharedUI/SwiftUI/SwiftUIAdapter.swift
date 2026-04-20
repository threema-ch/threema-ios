import Foundation
import SwiftUI

/// Adapter class to make SwiftUI-Views useable in Obj-C code
@objc final class SwiftUIAdapter: NSObject {
    
    private static var injectedContainer: AppContainer = .defaultValue
        
    @objc static func createDeleteSummaryView(
        onDismiss: @escaping () -> Void
    ) -> UIViewController {
        let deleteView = DeleteRevokeView(
            alreadyDeleted: true,
            onDismiss: onDismiss
        )
        let hostingController = DarkModeUIHostingController(rootView: deleteView)
        return hostingController
    }
}
