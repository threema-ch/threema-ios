import SwiftUI
import ThreemaMacros

struct IdentityThisDeviceOnlyDecisionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    @State var allowTransfer = true
    @State var showAlert = false
    
    var businessInjector: BusinessInjectorProtocol
    
    private let accessibilityThreshold = DynamicTypeSize.accessibility1
    
    var body: some View {
        ScrollView {
            VStack {
                Text(#localize("this_device_decision_title"))
                    .font(.title)
                    .bold()
                    .padding(.top, 48)
                
                Text(#localize("this_device_decision_info"))
                    .font(.headline)
                    .padding(.top)
                
                Text(#localize("this_device_decision_additional_info"))
                    .padding(.top)
                Link(
                    #localize("learn_more"),
                    destination: ThreemaURLProvider.thisDeviceOnlyFAQ
                )
                .padding(.bottom)
                
                GroupBox {
                    Toggle(isOn: $allowTransfer) {
                        Text(#localize("this_device_decision_toggle_title"))
                    }
                }
                .cornerRadius(30)
                
                Text(#localize("this_device_decision_view_footer"))
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                
                if dynamicTypeSize >= accessibilityThreshold {
                    ThreemaButton(
                        title: #localize("continue"),
                        style: .borderedProminent,
                        size: .fullWidth
                    ) {
                        continueTapped()
                    }
                    .padding(.vertical)
                }
            }
            .padding()
        }
        .alert(#localize("this_device_decision_alert_title"), isPresented: $showAlert, actions: {
            Button(#localize("this_device_decision_try_again"), role: .cancel) {
                dismiss()
            }
        }, message: {
            Text(#localize("this_device_decision_alert_message"))
        })
        .overlay(alignment: .bottom) {
            if dynamicTypeSize < accessibilityThreshold {
                ThreemaButton(
                    title: #localize("continue"),
                    style: .borderedProminent,
                    size: .fullWidth
                ) {
                    continueTapped()
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .tint(.accentColor)
        .multilineTextAlignment(.center)
        .scrollBounceBehavior(.basedOnSize)
        .interactiveDismissDisabled()
        .task {
            updateWithCurrentState()
        }
    }
    
    private func continueTapped() {
        do {
            try businessInjector.keychainManager.changeIdentityAccessibility(thisDeviceOnly: !allowTransfer)
            businessInjector.userSettings.didShowIdentityThisDeviceOnly = true
            dismiss()
        }
        catch {
            showAlert = true
        }
    }
    
    private func updateWithCurrentState() {
        do {
            // We only update with the value if we already shown this view before.
            guard businessInjector.userSettings.didShowIdentityThisDeviceOnly else {
                return
            }
            allowTransfer = try !(businessInjector.keychainManager.isIdentityThisDeviceOnly())
        }
        catch {
            showAlert = true
        }
    }
}

#Preview {
    IdentityThisDeviceOnlyDecisionView(businessInjector: BusinessInjector())
}
