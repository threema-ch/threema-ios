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

struct MultiDeviceWizardPreparationView: View {
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    
    @Binding var dismiss: Bool

    @State private var animate = false
    @State private var advance = false
    private var animation: Animation {
        Animation.linear(duration: 6.0)
            .repeatForever(autoreverses: false)
    }
    
    var body: some View {
        VStack {
            ZStack(alignment: .top) {
                
                MultiDeviceWizardConnectionInfoView()
                
                VStack {
                    Spacer()
                    
                    Image(systemName: "circle.dotted")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 130, height: 130)
                        .foregroundColor(Color(.primary))
                        .rotationEffect(Angle(degrees: animate ? 360 : 0.0))
                        .animation(animation, value: animate)
                        .accessibilityHidden(true)
                    
                    Text(BundleUtil.localizedString(forKey: "md_wizard_preparation_status"))
                        .font(.title2)
                        .bold()
                        .padding()
                    
                    Spacer()
                }
            }
            Button {
                dismiss = true
                wizardVM.cancelLinking()
            } label: {
                Text(BundleUtil.localizedString(forKey: "md_wizard_cancel"))
            }
            .buttonStyle(.bordered)
            .tint(Color(.primary))
        }
        .padding(.horizontal)
        
        .navigationBarTitle(BundleUtil.localizedString(forKey: "md_wizard_header"))
        .navigationBarBackButtonHidden()
        
        .onAppear {
            wizardVM.advanceState(.preparation)
            animate = true
        }
        .onDisappear {
            animate = false
        }
        .onChange(of: wizardVM.wizardState) { newValue in
            if newValue == .identity {
                advance = true
            }
        }
        
        NavigationLink(isActive: $advance) {
            MultiDeviceWizardIdentityView(wizardVM: wizardVM, dismiss: $dismiss)
        } label: {
            EmptyView()
        }
    }
}

// MARK: - Preview

struct MultiDeviceWizardTransmissionView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardPreparationView(wizardVM: MultiDeviceWizardViewModel(), dismiss: .constant(false))
    }
}
