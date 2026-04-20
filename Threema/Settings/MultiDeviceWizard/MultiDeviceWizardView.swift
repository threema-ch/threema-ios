import SwiftUI
import ThreemaMacros

struct MultiDeviceWizardView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @State private var path = NavigationPath()

    // MARK: - View
    
    var body: some View {
        NavigationStack(path: $path) {
            MultiDeviceWizardTermsView(wizardVM: wizardVM, path: $path)
                .padding(.horizontal)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarTitle(#localize("md_wizard_header"))
                .navigationDestination(for: MultiDeviceWizardNavigationRoute.self) { route in
                    switch route {
                    case .terms:
                        MultiDeviceWizardTermsView(wizardVM: wizardVM, path: $path)

                    case .info:
                        MultiDeviceWizardInformationView(wizardVM: wizardVM, path: $path)

                    case .preparation:
                        MultiDeviceWizardPreparationView(wizardVM: wizardVM, path: $path)

                    case .identity:
                        MultiDeviceWizardIdentityView(wizardVM: wizardVM, path: $path)

                    case .code:
                        MultiDeviceWizardCodeView(wizardVM: wizardVM, path: $path)

                    case .success:
                        MultiDeviceWizardSuccessView()
                    }
                }
        }
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

        .alert(
            String.localizedStringWithFormat(#localize("md_wizard_error_title"), TargetManager.appName),
            isPresented: $wizardVM.shouldDismiss
        ) {
            Button(#localize("ok"), role: .cancel) {
                wizardVM.cancelLinking()
                dismiss()
            }
        } message: {
            Text(#localize("md_wizard_error_text"))
        }
        
        .alert(#localize("md_wizard_timeout_title"), isPresented: $wizardVM.didTimeout) {
            Button(#localize("ok"), role: .cancel) {
                wizardVM.cancelLinking()
                dismiss()
            }
        } message: {
            Text(#localize("md_wizard_error_text"))
        }

        .alert(
            #localize("md_wizard_could_not_connect_title"),
            isPresented: $wizardVM.didDisconnect
        ) {
            Button(#localize("ok"), role: .cancel) {
                wizardVM.cancelLinking()
                dismiss()
            }
        } message: {
            Text(#localize("md_wizard_error_text"))
        }
    }
}
