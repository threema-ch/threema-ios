import SwiftUI
import ThreemaMacros

struct MultiDeviceWizardPreparationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var wizardVM: MultiDeviceWizardViewModel
    @Binding var path: NavigationPath
    @State private var animate = false

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
                        .foregroundColor(.accentColor)
                        .rotationEffect(Angle(degrees: animate ? 360 : 0.0))
                        .animation(animation, value: animate)
                        .accessibilityHidden(true)
                    
                    Text(#localize("md_wizard_preparation_status"))
                        .font(.title2)
                        .bold()
                        .padding()
                    
                    Spacer()
                }
            }
            Button {
                dismiss()
                wizardVM.cancelLinking()
            } label: {
                Text(#localize("md_wizard_cancel"))
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
        }
        .padding(.horizontal)
        .navigationBarTitle(#localize("md_wizard_header"))
        .navigationBarBackButtonHidden()
        .onAppear {
            wizardVM.advanceState(.preparation)
            animate = true
        }
        .onDisappear {
            animate = false
        }
        .onChange(of: wizardVM.wizardState) {
            if wizardVM.wizardState == .identity {
                path.append(MultiDeviceWizardNavigationRoute.identity)
            }
        }
    }
}

// MARK: - Preview

struct MultiDeviceWizardTransmissionView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardPreparationView(
            wizardVM: MultiDeviceWizardViewModel(),
            path: .constant(.init())
        )
    }
}
