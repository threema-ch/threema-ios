//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

struct MultiDeviceWizardIdentityView: View {
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @Binding var dismiss: Bool

    var identity = MyIdentityStore.shared().identity!
    
    var body: some View {
        VStack {
            ZStack(alignment: .top) {
                
                MultiDeviceWizardConnectionInfoView()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    Text(String.localizedStringWithFormat(
                        #localize("md_wizard_start_desktop"),
                        TargetManager.appName,
                        TargetManager.localizedAppName
                    ))
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 30)
                    
                    Text(String.localizedStringWithFormat(
                        #localize("md_wizard_identity_text"),
                        TargetManager.localizedAppName
                    ))
                    .bold()
                    .font(.title2)
                    .padding(.bottom)
                    
                    Text(identity)
                        .font(.system(.title, design: .monospaced))
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color(uiColor: Colors.backgroundWizardBox))
                        .cornerRadius(15)
                        .onTapGesture {
                            UIPasteboard.general.string = identity
                            NotificationPresenterWrapper.shared.present(type: .copySuccess)
                        }
                        .speechSpellsOutCharacters()
                    
                    Spacer()
                }
            }
            
            HStack {
                Button {
                    dismiss = true
                    wizardVM.cancelLinking()
                } label: {
                    Text(#localize("md_wizard_cancel"))
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                
                Spacer()
                
                NavigationLink {
                    MultiDeviceWizardCodeView(wizardVM: wizardVM, dismissModal: $dismiss)
                    
                } label: {
                    Text(#localize("md_wizard_next"))
                        .bold()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
        .navigationBarTitle(#localize("md_wizard_header"))
        .navigationBarBackButtonHidden()
        .onAppear {
            wizardVM.advanceState(.identity)
        }
    }
}

// MARK: - Preview

struct MultiDeviceWizardIdentityView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardIdentityView(wizardVM: MultiDeviceWizardViewModel(), dismiss: .constant(false))
    }
}
