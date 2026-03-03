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

struct RemoteSecretActivateDeactivateView: View {
    @StateObject var viewModel: RemoteSecretActivateDeactivateViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text(viewModel.type.title)
                    .font(.title)
                    .bold()
                    .padding()
                
                GroupBox {
                    Text(viewModel.type.boxText)
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom)
                
                Spacer()
                
                Button {
                    dismiss()
                    NotificationCenter.default.post(name: Notification.Name(kNotificationShowProfile), object: nil)
                } label: {
                    Text(viewModel.createBackupButtonTitle)
                }
                .buttonStyle(.threemaProminentButtonStyle)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                NavigationLink {
                    DeleteRevokeView {
                        dismiss()
                    }
                } label: {
                    Text(viewModel.removeButtonTitle)
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 8)
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                Button {
                    dismiss()
                } label: {
                    Text(viewModel.notNowButtonTitle)
                        .font(.title3)
                        .bold()
                }
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .ignoresSafeArea(.all, edges: [.horizontal])
        }
    }
}

#Preview {
    RemoteSecretActivateDeactivateView(viewModel: RemoteSecretActivateDeactivateViewModel(type: .activate))
}
