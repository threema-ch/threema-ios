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

struct MultiDeviceWizardTermsView: View {
    
    var hasPFSEnabledContacts: Bool
    @Binding var didAcceptTerms: Bool
    
    @State var shouldShowAlert = false
    
    let bulletImageName = "info.circle.fill"
    let paddingSize: CGFloat = 8
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // MARK: - Banner
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(BundleUtil.localizedString(forKey: "md_wizard_terms_note_text"))
                    }
                    Spacer()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(uiColor: Colors.backgroundWizardBox))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .padding(.bottom)
                
                // MARK: - Bullet Points

                VStack(alignment: .leading, spacing: 0) {
                    
                    MultiDeviceWizardBulletPointView(
                        text: BundleUtil.localizedString(forKey: "md_wizard_terms_backup"),
                        imageName: bulletImageName
                    )
                    .padding(.bottom, paddingSize)
                    
                    MultiDeviceWizardBulletPointView(
                        text: BundleUtil.localizedString(forKey: "md_wizard_terms_support"),
                        imageName: bulletImageName
                    )
                    .padding(.bottom, paddingSize)
                    
                    MultiDeviceWizardBulletPointView(
                        text: BundleUtil.localizedString(forKey: "md_wizard_terms_issues"),
                        imageName: bulletImageName
                    )
                    .highPriorityGesture(DragGesture())
                    .padding(.bottom, paddingSize)
                    
                    MultiDeviceWizardBulletPointView(
                        text: BundleUtil.localizedString(forKey: "md_wizard_terms_bugs"),
                        imageName: bulletImageName
                    )
                    .padding(.bottom, paddingSize)
                }
                .padding(.vertical)
                
                // MARK: - Terms Toggle
                
                Toggle(isOn: $didAcceptTerms) {
                    Text(BundleUtil.localizedString(forKey: "md_wizard_terms_accept"))
                        .font(.headline)
                }
                .tint(Color(Colors.primary))
                .padding(.trailing)
                
                .onChange(of: didAcceptTerms) { newValue in
                    if hasPFSEnabledContacts {
                        shouldShowAlert = newValue
                    }
                }
                
                Spacer()
            }
        }
        .alert(BundleUtil.localizedString(forKey: "forward_security"), isPresented: $shouldShowAlert, actions: {
            Button(BundleUtil.localizedString(forKey: "md_wizard_disable_pfs_confirm"), role: .destructive) {
                // Termination will be sent when linking completes
            }
            Button(BundleUtil.localizedString(forKey: "cancel"), role: .cancel) {
                didAcceptTerms = false
            }
            
        }, message: {
            Text(BundleUtil.localizedString(forKey: "md_wizard_pfs_warning"))
        })
        .onDisappear {
            didAcceptTerms = false
        }
    }
}

// MARK: - Preview

struct MultiDeviceWizardIntroView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardTermsView(
            hasPFSEnabledContacts: true,
            didAcceptTerms: .constant(true)
        )
    }
}
