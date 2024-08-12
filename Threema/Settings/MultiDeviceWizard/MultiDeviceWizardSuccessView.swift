//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

struct MultiDeviceWizardSuccessView: View {
    @Binding var dismiss: Bool

    var body: some View {
        VStack(spacing: 5) {
            Spacer()

            Image("PartyPopper")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .padding(50)
                .accessibilityHidden(true)
            
            Text(BundleUtil.localizedString(forKey: "md_wizard_success_title"))
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
            
            Text(BundleUtil.localizedString(forKey: "md_wizard_success_text"))
                .multilineTextAlignment(.center)

            Spacer()
            Spacer()
            
            Button {
                dismiss = true
                
            } label: {
                Text(BundleUtil.localizedString(forKey: "md_wizard_close"))
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .navigationBarBackButtonHidden()
        }
    }
}

// MARK: - Preview

struct MultiDeviceWizardSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardSuccessView(dismiss: .constant(false))
    }
}
