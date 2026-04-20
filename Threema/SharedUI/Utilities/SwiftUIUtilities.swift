import Foundation
import SwiftUI
import ThreemaFramework

extension View {
    var topViewController: UIViewController? {
        AppDelegate.shared().currentTopViewController()
    }
    
    func loadingOverlay(_ isLoading: Bool) -> some View {
        overlay {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial.opacity(0.9))
                    .edgesIgnoringSafeArea(.all)
                    .controlSize(.large)
            }
        }
        .allowsHitTesting(!isLoading)
    }
}
