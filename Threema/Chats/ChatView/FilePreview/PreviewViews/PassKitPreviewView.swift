import PassKit
import SwiftUI
import ThreemaFramework

struct PassKitPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PassKitPreviewViewModel
    
    var body: some View {
        Group {
            if viewModel.shouldShowPass, let pkPass = viewModel.pkPass {
                PassKitRepresentable(
                    pkPass: pkPass,
                    fallback: PreviewUnavailableView(
                        viewModel: PreviewUnavailableViewModel(
                            fileMessageEntity: viewModel.fileMessageEntity
                        )
                    )
                )
                .ignoresSafeArea()
            }
            else if viewModel.shouldShowFailure {
                PreviewUnavailableView(
                    viewModel: PreviewUnavailableViewModel(
                        fileMessageEntity: viewModel.fileMessageEntity
                    )
                )
            }
            else {
                ProgressView()
            }
        }
        .task {
            viewModel.loadPass()
        }
    }
}

struct PassKitRepresentable<Fallback: View>: UIViewControllerRepresentable {
    let pkPass: PKPass
    let fallback: Fallback

    func makeUIViewController(context: Context) -> UIViewController {
        if let passVC = PKAddPassesViewController(pass: pkPass) {
            passVC
        }
        else {
            UIHostingController(rootView: fallback)
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}
