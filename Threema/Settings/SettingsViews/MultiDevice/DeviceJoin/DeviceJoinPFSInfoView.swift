import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct DeviceJoinPFSInfoView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var deviceJoinManager: DeviceJoinManager
    @Binding var showWizard: Bool
    @Binding var path: NavigationPath

    var body: some View {
        VStack {
            ScrollView {
                DeviceJoinHeaderView(
                    title: String.localizedStringWithFormat(
                        #localize("settings_list_threema_desktop_title"),
                        TargetManager.appName
                    ),
                    description: String.localizedStringWithFormat(
                        #localize("multi_device_join_perfect_forward_secrecy_info"),
                        ThreemaURLProvider.multiDeviceLimit.absoluteString
                    )
                )
                .padding([.horizontal, .top], 24)
                .accessibilityAction(named: Text(String.localizedStringWithFormat(
                    #localize("accessibility_action_open_link"),
                    ThreemaURLProvider.multiDeviceLimit.absoluteString
                ))) {
                    openURL(ThreemaURLProvider.multiDeviceLimit)
                }
            }
            
            Spacer()
            
            ThreemaButton(
                title: #localize("multi_device_new_linked_devices_add_button"),
                style: .bordered,
                size: .fullWidth
            ) {
                path.append(DeviceJoinRoute.scanQRCode)
            }
            .padding([.horizontal, .bottom], 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                XMarkCancelButton {
                    showWizard = false
                }
            }
        }
    }
}

struct DeviceJoinPFSInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DeviceJoinPFSInfoView(
                deviceJoinManager: DeviceJoinManager(),
                showWizard: .constant(true),
                path: .constant(.init())
            )
        }
    }
}
