import SwiftUI

struct DeviceJoinView: View {
    @EnvironmentObject var settingsStore: SettingsStore

    @Binding var showWizard: Bool
    
    // Note: This seems not be be correctly deallocated in some cases even though the view is dismissed.
    // (e.g. when the "No match?" alert is closed in during the emoji verification. Because linking
    // is not often used we don't expect significant memory leaks by that. (IOS-3908)
    @StateObject private var manager = DeviceJoinManager()

    // Workaround reactiveness: This should not be changed after the view initially appears
    @State private var isMultiDeviceRegistered = false

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Color.clear
                .navigationDestination(for: DeviceJoinRoute.self) { route in
                    switch route {
                    case .pfsInfo:
                        DeviceJoinPFSInfoView(deviceJoinManager: manager, showWizard: $showWizard, path: $path)

                    case .scanQRCode:
                        DeviceJoinScanQRCodeView(deviceJoinManager: manager, showWizard: $showWizard, path: $path)

                    case .verifyEmoji:
                        DeviceJoinVerifyEmojiView(deviceJoinManager: manager, showWizard: $showWizard, path: $path)

                    case .sendData:
                        DeviceJoinSendDataView(deviceJoinManager: manager, showWizard: $showWizard, path: $path)

                    case .success:
                        DeviceJoinSuccessView(showWizard: $showWizard)
                    }
                }
        }
        .onAppear {
            if settingsStore.isMultiDeviceRegistered {
                path.append(DeviceJoinRoute.scanQRCode)
            }
            else {
                path.append(DeviceJoinRoute.pfsInfo)
            }
        }
    }
}

struct DeviceJoinView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceJoinView(showWizard: .constant(true))
    }
}
