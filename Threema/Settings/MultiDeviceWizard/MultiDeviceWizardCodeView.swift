import SwiftUI
import ThreemaMacros

struct MultiDeviceWizardCodeView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @Binding var path: NavigationPath

    @State var animate = false

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
                        .foregroundColor(.accentColor)
                        .rotationEffect(Angle(degrees: animate ? 360 : 0.0))
                        .animation(animation, value: animate)
                        .accessibilityHidden(true)
                    
                    Spacer()
                }
            }
            
            Button {
                dismiss()
            } label: {
                Text(String.localizedStringWithFormat(
                    #localize("md_wizard_back_identity"),
                    TargetManager.localizedAppName
                ))
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
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
        .onChange(of: wizardVM.wizardState) {
            if wizardVM.wizardState == .success {
                path.append(MultiDeviceWizardNavigationRoute.success)
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
        
        .onChange(of: wizardVM.linkingCode) {
            blocks = wizardVM.linkingCode
        }
        .onTapGesture {
            UIPasteboard.general.string = blocks.joined(separator: "")
            NotificationPresenterWrapper.shared.present(type: .copySuccess)
        }
    }
}

struct MultiDeviceWizardLinkView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardCodeView(
            wizardVM: MultiDeviceWizardViewModel(),
            path: .constant(.init())
        )
    }
}
