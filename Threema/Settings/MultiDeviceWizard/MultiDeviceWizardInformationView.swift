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
import ThreemaMacros

struct MultiDeviceWizardInformationView: View {
    @Environment(\.openURL) var openURL
    @Environment(\.appContainer.businessInjector)
    private var injectedBusinessInjector: any BusinessInjectorProtocol
    
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @Binding var dismiss: Bool

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    
                    VStack(alignment: .leading, spacing: 0) {
                        MultiDeviceWizardBulletPointView(
                            text: #localize("md_wizard_info_download_title"),
                            imageName: "arrow.down.circle.fill"
                        )
                        .padding(.bottom, 2.0)
                        
                        Text(#localize("md_wizard_info_download_text"))
                        
                        Link(destination: URL(string: "https://three.ma/md")!) {
                            Text(verbatim: "three.ma/md")
                        }
                        .foregroundColor(Color(.primary))
                        .highPriorityGesture(DragGesture())
                    }
                    .padding(.top)
                    .accessibilityElement(children: .combine)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        MultiDeviceWizardBulletPointView(
                            text: #localize("md_wizard_info_linking_title"),
                            imageName: "link.circle.fill"
                        )
                        .padding(.bottom, 2.0)
                        
                        Text(LocalizedStringKey(String.localizedStringWithFormat(
                            #localize("md_wizard_info_linking_text"),
                            DeviceLinking(businessInjector: injectedBusinessInjector).threemaSafeServer
                        )))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAction(named: Text(String.localizedStringWithFormat(
                        #localize("accessibility_action_open_link"),
                        ThreemaURLProvider.safeWebdav.absoluteString
                    ))) {
                        openURL(ThreemaURLProvider.safeWebdav)
                    }
                }
            }
            Spacer()
                
            HStack {
                Button {
                    dismiss = true
                    wizardVM.cancelLinking()
                } label: {
                    Text(#localize("md_wizard_cancel"))
                }
                .buttonStyle(.bordered)
                .tint(Color(.primary))
                    
                Spacer()
                    
                NavigationLink {
                    MultiDeviceWizardPreparationView(wizardVM: wizardVM, dismiss: $dismiss)
                        
                } label: {
                    Text(#localize("md_wizard_start"))
                        .bold()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical)
        }
        .padding(.horizontal)
        .navigationBarTitle(#localize("md_wizard_header"))
        .navigationBarBackButtonHidden()
        .onAppear {
            wizardVM.advanceState(.information)
        }
    }
}

// MARK: - Preview

struct MultiDeviceWizardProcessView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardInformationView(wizardVM: MultiDeviceWizardViewModel(), dismiss: .constant(false))
    }
}
