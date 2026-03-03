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

import SwiftUI

struct RemoteSecretBlockView: View {
    @StateObject var viewModel: RemoteSecretBlockViewModel

    var body: some View {
        VStack {
            Spacer()
         
            Text(viewModel.type.title)
                .font(.title)
                .bold()
                .padding(.bottom, 2)
            Text(viewModel.type.description)
            
            Spacer()
            
            // Retry button
            if viewModel.showRetryButton {
                Button {
                    viewModel.retryButtonTapped()
                } label: {
                    Text(viewModel.retryButtonTitle)
                }
                .buttonStyle(.threemaProminentButtonStyle)
                .padding(.bottom, (viewModel.showDeleteButton || viewModel.showCancelButton) ? 8 : 0)
            }
            
            // Delete button
            if viewModel.showDeleteButton {
                Button {
                    viewModel.deleteButtonTapped()
                } label: {
                    Text(viewModel.deleteButtonTitle)
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.threemaPlainButtonStyle)
                .padding(.bottom, (viewModel.showCancelButton || viewModel.showCancelButton) ? 8 : 0)
                .confirmationDialog(
                    viewModel.alertTitle,
                    isPresented: $viewModel.showDeleteAlert,
                    titleVisibility: .visible,
                    actions: {
                        Button(
                            viewModel.alertConfirmButtonTitle,
                            role: .destructive
                        ) {
                            viewModel.delete()
                        }
                        
                        Button(viewModel.alertCancelButtonTitle, role: .cancel) {
                            // Do nothing
                        }
                    }
                )
            }
            
            // Cancel button
            if viewModel.showCancelButton {
                Button {
                    viewModel.cancelButtonTapped()
                } label: {
                    Text(viewModel.cancelButtonTitle)
                }
                .buttonStyle(.threemaPlainButtonStyle)
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .ignoresSafeArea(.all, edges: [.top, .horizontal])
    }
}

#Preview {
    RemoteSecretBlockView(viewModel: RemoteSecretBlockViewModel(
        type: .generalError,
        onRetry: nil,
        onDelete: nil,
        onCancel: nil
    ))
}
