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
                                Button(role: .cancel) {
                                    dismiss()
                                } label: {
                                    Label(viewModel.doneButtonTitle, systemImage: "xmark.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundColor(.secondary)
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
        previewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: quickLookPreviewViewModel.doneButtonTitle,
            style: .done,
            target: context.coordinator,
            action: #selector(Coordinator.didTapDone)
        )

        let navController = UINavigationController(rootViewController: previewController)
        return navController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL, dismiss: dismiss)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
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
