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

struct MultiDeviceWizardCodeView: View {
    @Environment(\.dismiss) var dismiss

    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @Binding var dismissModal: Bool

    @State var animate = false
    @State var advance = false
    
    var animation: Animation {
        Animation.linear(duration: 6.0)
            .repeatForever(autoreverses: false)
    }
    
    var body: some View {
        VStack {
            ZStack(alignment: .top) {
                
                MultiDeviceWizardConnectionInfoView()
                
                VStack(spacing: 0) {
                    Spacer()
                    Spacer()
                    Spacer()
                    
                    Text(#localize("md_wizard_code_text"))
                        .bold()
                        .font(.title2)
                        .padding(.bottom)
                    
                    MultiDeviceWizardCodeBlockView(wizardVM: wizardVM)
                        .highPriorityGesture(DragGesture())
                    
                    Spacer()
                    
                    Image(systemName: "circle.dotted")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 130, height: 130)
                        .foregroundColor(Color(.primary))
                        .rotationEffect(Angle(degrees: animate ? 360 : 0.0))
                        .animation(animation, value: animate)
                        .accessibilityHidden(true)
                    
                    Spacer()
                }
            }
            
            Button {
                dismiss()
            } label: {
                Text(#localize("md_wizard_back_identity"))
            }
            .buttonStyle(.bordered)
            .tint(Color(.primary))
            
            NavigationLink(isActive: $advance) {
                MultiDeviceWizardSuccessView(dismiss: $dismissModal)
            } label: {
                EmptyView()
            }
        }
        .padding(.horizontal)
        .navigationBarTitle(#localize("md_wizard_header"))
        .navigationBarBackButtonHidden()
        .onAppear {
            animate = true
            wizardVM.advanceState(.code)
        }
        .onDisappear {
            animate = false
        }
        .onChange(of: wizardVM.wizardState) { newValue in
            if newValue == .success {
                advance = true
            }
        }
    }
}

private struct MultiDeviceWizardCodeBlockView: View {
    
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    
    @State var blocks = [String]()
    
    var body: some View {
        HStack {
            ForEach(wizardVM.linkingCode, id: \.self) { block in
                Text(block)
                    .speechSpellsOutCharacters()
                    .font(.system(.title3, design: .monospaced))
                    .bold()
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding()
                    .background(Color(uiColor: Colors.backgroundWizardBox))
                    .cornerRadius(15)
            }
        }
        
        .onChange(of: wizardVM.linkingCode, perform: { newValue in
            blocks = newValue
        })
        .onTapGesture {
            UIPasteboard.general.string = blocks.joined(separator: "")
            NotificationPresenterWrapper.shared.present(type: .copySuccess)
        }
    }
}

struct MultiDeviceWizardLinkView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardCodeView(wizardVM: MultiDeviceWizardViewModel(), dismissModal: .constant(true))
    }
}
