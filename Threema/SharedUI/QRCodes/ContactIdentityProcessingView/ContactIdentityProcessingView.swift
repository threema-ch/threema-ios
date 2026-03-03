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
import ThreemaMacros

struct ContactIdentityProcessingView: View {
    @Bindable var model: ContactIdentityProcessingViewModel

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(#localize("contact_identity_processing"))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .navigationBarBackButtonHidden()
        .interactiveDismissDisabled()
        .onAppear {
            model.onAppear()
        }
        .alert(item: $model.alert) { alertData in
            Alert(
                title: Text(alertData.title),
                message: alertData.message.map { Text($0) },
                dismissButton: .default(Text(#localize("ok"))) {
                    model.alertOKButtonTapped()
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .cancel) {
                    model.onCompletion?(nil)
                } label: {
                    Label(#localize("cancel"), systemImage: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    ContactIdentityProcessingView(
        model: ContactIdentityProcessingViewModel(
            expectedIdentity: nil,
            scannedIdentity: .init(rawValue: "A123456"),
            scannedPublicKey: Data(),
            scannedExpirationDate: nil,
            systemFeedbackManager: .null
        )
    )
}
