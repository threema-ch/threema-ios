//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
