import SwiftUI
import ThreemaMacros

struct QrCodeView: View {
    weak var coordinator: ProfileCoordinator?
    let identityStore: MyIdentityStore
    var image: UIImage?
    
    init(coordinator: ProfileCoordinator, businessInjector: BusinessInjector = BusinessInjector.ui) {
        self.coordinator = coordinator
        self.identityStore = businessInjector.myIdentityStore as! MyIdentityStore
        
        if let identity = identityStore.identity, let key = identityStore.publicKey {
            let qrString = "3mid:\(identity),\(key.hexString)"
            self.image = QRCodeGenerator.generateQRCode(for: qrString)
        }
    }
    
    var body: some View {
        VStack {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .accessibilityIgnoresInvertColors(true)
                    .padding(16)
                    .accessibilityLabel(#localize("profile_big_qr_code"))
            }
            else {
                Text(verbatim: "Error")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                DoneButton {
                    coordinator?.dismiss()
                }
                .accessibilityIdentifier("close")
            }
        }
        .navigationTitle(#localize("profile_qr_code_title"))
    }
}
