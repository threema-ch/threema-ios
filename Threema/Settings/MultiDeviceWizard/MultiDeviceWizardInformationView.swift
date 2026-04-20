import SwiftUI
import ThreemaMacros

struct MultiDeviceWizardInformationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @Environment(\.appContainer.businessInjector)
    private var injectedBusinessInjector: any BusinessInjectorProtocol
    
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @Binding var path: NavigationPath

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
                        
                        Text(String.localizedStringWithFormat(
                            #localize("md_wizard_info_download_text"),
                            TargetManager.localizedAppName
                        ))
                        
                        Link(destination: URL(string: "https://three.ma/md")!) {
                            Text(verbatim: "three.ma/md")
                        }
                        .foregroundColor(.accentColor)
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
                            TargetManager.appName,
                            TargetManager.localizedAppName,
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
                    dismiss()
                    wizardVM.cancelLinking()
                } label: {
                    Text(#localize("md_wizard_cancel"))
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                    
                Spacer()
                    
                Button {
                    path.append(MultiDeviceWizardNavigationRoute.preparation)
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
        MultiDeviceWizardInformationView(
            wizardVM: MultiDeviceWizardViewModel(),
            path: .constant(.init())
        )
    }
}
