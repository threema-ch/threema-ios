import ContactsUI
import SwiftUI

struct ContactPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ContactPreviewViewModel

    var body: some View {
        Group {
            if viewModel.isAuthorized {
                ContactPreviewRepresentable(
                    entity: viewModel.fileMessageEntity,
                    fallback: PreviewUnavailableView(
                        viewModel: PreviewUnavailableViewModel(
                            fileMessageEntity: viewModel.fileMessageEntity
                        )
                    )
                )
                .ignoresSafeArea()
            }
            else {
                ProgressView()
            }
        }
        .task {
            viewModel.checkContactAccess()
        }
        .alert(
            viewModel.alertTitle,
            isPresented: $viewModel.showAlert,
            actions: {
                Button(viewModel.alertOpenSettingsButtonTitle) {
                    viewModel.openSettings()
                    dismiss()
                }

                Button(viewModel.alertCancelButtonTitle, role: .cancel) {
                    dismiss()
                }
            },
            message: {
                Text(viewModel.alertMessage)
            }
        )
    }
}

struct ContactPreviewRepresentable<Fallback: View>: UIViewControllerRepresentable {
    let entity: FileMessageEntity
    let fallback: Fallback

    func makeUIViewController(context: Context) -> UIViewController {
        guard
            let data = entity.data?.data,
            let contact = try? CNContactVCardSerialization.contacts(with: data).first
        else {
            return UIHostingController(rootView: fallback)
        }

        let controller = CNContactViewController(forUnknownContact: contact)
        controller.allowsEditing = false
        controller.allowsActions = !MDMSetup().disableShareMedia()
        controller.contactStore = CNContactStore()

        if #unavailable(iOS 17.0) {
            controller.edgesForExtendedLayout = []
        }

        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}
