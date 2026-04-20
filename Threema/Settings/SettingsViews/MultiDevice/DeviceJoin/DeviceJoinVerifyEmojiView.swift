import SwiftUI
import ThreemaMacros

struct DeviceJoinVerifyEmojiView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var deviceJoinManager: DeviceJoinManager
    @Binding var showWizard: Bool
    @Binding var path: NavigationPath
    @State private var showNoMatchAlert = false
    @State private var startSendData = false
    
    var body: some View {
        GeometryReader { geometryProxy in
            ScrollView {
                VStack(alignment: .center) {
                    
                    DeviceJoinHeaderView(
                        title: #localize("multi_device_join_trust_new_device_title"),
                        description: #localize("multi_device_join_trust_new_device_info")
                    )
                    .padding(.bottom, 24)
                    
                    if case let .verifyRendezvousConnection(rendezvousPathHash: rendezvousPathHash) = deviceJoinManager
                        .viewState {
                        VStack {
                            RendezvousEmojisView(
                                rendezvousHash: rendezvousPathHash,
                                rendezvousHashConfirmed: $startSendData
                            )
                            .frame(maxWidth: !dynamicTypeSize.isAccessibilitySize ? 250 : nil)
                            .padding(.bottom, 24)
                            
                            Button(#localize("multi_device_join_no_match_button")) {
                                showNoMatchAlert = true
                            }
                        }
                    }
                    else {
                        // This should never happen
                        VStack {
                            Text(
                                verbatim: "An unexpected error occurred. Please restart the app on the new device and try again."
                            )
                            .multilineTextAlignment(.center)
                            
                            ThreemaButton(
                                title: #localize("ok"),
                                role: .destructive,
                                style: .borderedProminent,
                                size: .fullWidth
                            ) {
                                deviceJoinManager.deviceJoin.cancel()
                                showWizard = false
                            }
                        }
                    }
                    
                    Spacer(minLength: 24)

                    Label(
                        String.localizedStringWithFormat(
                            #localize("multi_device_join_sending_info"),
                            TargetManager.appName
                        ),
                        systemImage: "info.circle"
                    )
                    .foregroundColor(.secondary)
                    .font(.footnote)
                }
                .padding([.horizontal, .bottom], 24)
                .frame(minHeight: geometryProxy.size.height)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        // If this is set higher in the navigation stack this will be overridden by it
        .interactiveDismissDisabled()
        .onChange(of: startSendData) {
            if startSendData {
                path.append(DeviceJoinRoute.sendData)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                XMarkCancelButton {
                    deviceJoinManager.deviceJoin.cancel()
                    showWizard = false
                }
            }
        }
        .alert(#localize("multi_device_join_no_match_title"), isPresented: $showNoMatchAlert) {
            Button(#localize("ok")) {
                deviceJoinManager.deviceJoin.cancel()
                showWizard = false
            }
        } message: {
            Text(#localize("multi_device_join_no_match_message"))
        }
    }
}

struct DeviceJoinVerifyEmojiView_Previews: PreviewProvider {
    
    static var deviceJoinManager: DeviceJoinManager {
        let deviceJoinManager = DeviceJoinManager()
        try! deviceJoinManager.advance(to: .establishRendezvousConnection)
        try! deviceJoinManager.advance(to: .verifyRendezvousConnection(rendezvousPathHash: Data([
            0x58, 0x02, 0x88, 0xFA, 0x0E, 0xEE, 0x0A, 0xF1, 0x6A, 0x76, 0xBE, 0x8D,
        ])))
        return deviceJoinManager
    }
    
    static var previews: some View {
        NavigationView {
            DeviceJoinVerifyEmojiView(
                deviceJoinManager: deviceJoinManager,
                showWizard: .constant(true),
                path: .constant(.init())
            )
        }
    }
}
