import SwiftUI
import ThreemaFramework

struct LockCoverView: View {
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            Image(uiImage: .lockCover)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 290, maxHeight: 20)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }
}

@objc public final class LockCoverViewProvider: NSObject {
    @objc static let lockCoverViewController: UIViewController = UIHostingController(rootView: LockCoverView())
}

#Preview {
    LockCoverView()
}
