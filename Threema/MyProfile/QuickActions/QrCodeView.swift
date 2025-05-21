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
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    coordinator?.dismiss()
                } label: {
                    Text(#localize("Done"))
                }
            }
        }
        .navigationTitle(#localize("profile_qr_code_title"))
    }
}
