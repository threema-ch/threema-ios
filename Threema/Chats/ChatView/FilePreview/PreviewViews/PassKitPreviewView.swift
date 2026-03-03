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
