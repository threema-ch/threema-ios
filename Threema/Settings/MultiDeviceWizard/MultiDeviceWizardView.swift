//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

struct MultiDeviceWizardView: View {
    @Environment(\.dismiss) var dismiss
    @State var dismissView = false
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    
    // MARK: - View
    
    var body: some View {
        NavigationView {
            MultiDeviceWizardTermsView(
                wizardVM: wizardVM,
                dismiss: $dismissView,
                hasPFSEnabledContacts: wizardVM.hasPFSEnabledContacts
            )
            .padding(.horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitle(BundleUtil.localizedString(forKey: "md_wizard_header"))
        }
        .onAppear {
            if UIDevice.current.userInterfaceIdiom == .phone {
                // Forcing the rotation to portrait and lock it
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                AppDelegate.shared().orientationLock = .portrait
            }
            dismissView = false
        }
        .onDisappear(perform: {
            // Unlocking the rotation
            AppDelegate.shared().orientationLock = .all
        })
        .onChange(of: dismissView, perform: { _ in
            if dismissView {
                dismiss()
            }
        })
        
        .alert(BundleUtil.localizedString(forKey: "md_wizard_error_title"), isPresented: $wizardVM.shouldDismiss) {
            Button(BundleUtil.localizedString(forKey: "ok"), role: .cancel) {
                wizardVM.cancelLinking()
                dismiss()
            }
        } message: {
            Text(BundleUtil.localizedString(forKey: "md_wizard_error_text"))
        }
        
        .alert(BundleUtil.localizedString(forKey: "md_wizard_timeout_title"), isPresented: $wizardVM.didTimeout) {
            Button(BundleUtil.localizedString(forKey: "ok"), role: .cancel) {
                wizardVM.cancelLinking()
                dismiss()
            }
        } message: {
            Text(BundleUtil.localizedString(forKey: "md_wizard_error_text"))
        }

        .alert(
            BundleUtil.localizedString(forKey: "md_wizard_could_not_connect_title"),
            isPresented: $wizardVM.didDisconnect
        ) {
            Button(BundleUtil.localizedString(forKey: "ok"), role: .cancel) {
                wizardVM.cancelLinking()
                dismiss()
            }
        } message: {
            Text(BundleUtil.localizedString(forKey: "md_wizard_error_text"))
        }
    }
}

// MARK: - Preview

struct MultiDeviceWizardView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}
