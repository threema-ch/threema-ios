import SwiftUI
import ThreemaMacros

struct MultiDeviceWizardIdentityView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @Binding var path: NavigationPath

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
                    dismiss()
                    wizardVM.cancelLinking()
                } label: {
                    Text(#localize("md_wizard_cancel"))
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                
                Spacer()
                
                Button {
                    path.append(MultiDeviceWizardNavigationRoute.code)
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
        MultiDeviceWizardIdentityView(
            wizardVM: MultiDeviceWizardViewModel(),
            path: .constant(.init())
        )
    }
}
