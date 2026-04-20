import QuickLook
import SwiftUI

struct QuickLookPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: QuickLookPreviewViewModel
    
    var body: some View {
        Group {
            if viewModel.shouldShowPreview, let tempFileURL = viewModel.tempFileURL {
                if ThreemaQLPreviewController.canPreview(tempFileURL as NSURL) {
                    ThreemaQLPreviewControllerWrapper(
                        fileURL: tempFileURL,
                        quickLookPreviewViewModel: viewModel,
                        dismiss: {
                            dismiss()
                        }
                    )
                    .ignoresSafeArea()
                }
                else {
                    // We add our own navigation bar as `ThreemaQLPreviewController` brings his own navigation bar, too
                    NavigationView {
                        PreviewUnavailableView(
                            viewModel: PreviewUnavailableViewModel(
                                fileMessageEntity: viewModel.fileMessageEntity
                            )
                        )
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                XMarkCancelButton {
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            else {
                ProgressView()
            }
        }
        .task {
            viewModel.load()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

struct ThreemaQLPreviewControllerWrapper: UIViewControllerRepresentable {
    let fileURL: URL
    let quickLookPreviewViewModel: QuickLookPreviewViewModel
    let dismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let previewController = ThreemaQLPreviewController()
        previewController.dataSource = context.coordinator
        previewController.delegate = context.coordinator
        previewController.navigationItem.rightBarButtonItem = UIBarButtonItem.closeButton(
            target: context.coordinator,
            selector: #selector(Coordinator.didTapDone)
        )

        let navController = UINavigationController(rootViewController: previewController)
        return navController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL, dismiss: dismiss)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let fileURL: URL
        let dismiss: () -> Void

        init(fileURL: URL, dismiss: @escaping () -> Void) {
            self.fileURL = fileURL
            self.dismiss = dismiss
        }
        
        @objc func didTapDone() {
            dismiss()
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            fileURL as NSURL
        }
    }
}
