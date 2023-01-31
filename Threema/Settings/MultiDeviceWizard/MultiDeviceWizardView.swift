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
    
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    
    @State var didAcceptTerms = false

    // MARK: - View
    
    var body: some View {

        VStack {
            // MARK: - Title
            
            Text(BundleUtil.localizedString(forKey: "md_wizard_header"))
                .font(.title2)
                .bold()
                .padding()
            
            // MARK: - TabView

            TabView(selection: $wizardVM.wizardState) {
                MultiDeviceWizardTermsView(
                    hasPFSEnabledContacts: wizardVM.hasPFSEnabledContacts,
                    didAcceptTerms: $didAcceptTerms
                )
                .tag(WizardState.terms)
                .wizardTabView()
                
                MultiDeviceWizardInformationView()
                    .tag(WizardState.information)
                    .wizardTabView()
                
                MultiDeviceWizardPreparationView()
                    .tag(WizardState.preparation)
                    .wizardTabView()
                
                MultiDeviceWizardIdentityView()
                    .tag(WizardState.identity)
                    .wizardTabView()
                
                MultiDeviceWizardCodeView(wizardVM: wizardVM)
                    .tag(WizardState.code)
                    .wizardTabView()
                
                MultiDeviceWizardSuccessView()
                    .tag(WizardState.success)
                    .wizardTabView()
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // MARK: - Buttons
            
            MultiDeviceWizardButtonsView(wizardVM: wizardVM, didAcceptTerms: $didAcceptTerms)
        }
        .padding()
        .onAppear {
            if UIDevice.current.userInterfaceIdiom == .phone {
                // Forcing the rotation to portrait and lock it
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                AppDelegate.shared().orientationLock = .portrait
            }
        }
        .onDisappear(perform: {
            // Unlocking the rotation
            AppDelegate.shared().orientationLock = .all
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

// MARK: - Buttons

struct MultiDeviceWizardButtonsView: View {
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @Binding var didAcceptTerms: Bool
    
    var body: some View {
        switch wizardVM.wizardState {
        case .preparation, .code:
            MultiDeviceWizardCancelButtonView(wizardVM: wizardVM, didAcceptTerms: $didAcceptTerms)
            
        case .success:
            MultiDeviceWizardNextButtonView(wizardVM: wizardVM, didAcceptTerms: $didAcceptTerms)
            
        default:
            HStack {
                MultiDeviceWizardCancelButtonView(wizardVM: wizardVM, didAcceptTerms: $didAcceptTerms)
                Spacer()
                MultiDeviceWizardNextButtonView(wizardVM: wizardVM, didAcceptTerms: $didAcceptTerms)
            }
        }
    }
}

struct MultiDeviceWizardCancelButtonView: View {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @Binding var didAcceptTerms: Bool
    
    var body: some View {
        Button {
            switch wizardVM.wizardState {
            case .code:
                wizardVM.advanceState(.identity)
            default:
                wizardVM.cancelLinking()
                didAcceptTerms = false
                dismiss()
            }
            
        } label: {
            switch wizardVM.wizardState {
            case .code:
                Text(BundleUtil.localizedString(forKey: "md_wizard_back_identity"))

            default:
                Text(BundleUtil.localizedString(forKey: "md_wizard_cancel"))
            }
        }
        .buttonStyle(.bordered)
        .tint(Color(Colors.primary))
    }
}

struct MultiDeviceWizardNextButtonView: View {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @Binding var didAcceptTerms: Bool
    
    var body: some View {
        Button {
            withAnimation {
                if wizardVM.wizardState == .success {
                    dismiss()
                    return
                }
                
                wizardVM.advanceState()
            }
        } label: {
            switch wizardVM.wizardState {
            case .information:
                Text(BundleUtil.localizedString(forKey: "md_wizard_start"))
                    .bold()
                
            case .success:
                Text(BundleUtil.localizedString(forKey: "md_wizard_close"))
                    .bold()
                
            default:
                Text(BundleUtil.localizedString(forKey: "md_wizard_next"))
                    .bold()
            }
        }
        .disabled(isNextDisabled())
        .buttonStyle(.borderedProminent)
    }
    
    // MARK: - Private Functions

    private func isNextDisabled() -> Bool {
        switch wizardVM.wizardState {
        case .terms:
            return !didAcceptTerms
        default:
            return false
        }
    }
}

// MARK: - Custom modifiers

struct WizardTabViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture())
    }
}

private extension View {
    func wizardTabView() -> some View {
        modifier(WizardTabViewModifier())
    }
}

// MARK: - Preview

struct MultiDeviceWizardView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}
