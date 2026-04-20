import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct NotificationsAndAlertsView: View {
    var body: some View {
        List {
            Section {
                ForEach(notifications, id: \.name) { name, userInfo in
                    Button {
                        center.post(Notification(name: name, object: nil, userInfo: userInfo))
                    } label: {
                        Text(verbatim: name.rawValue)
                    }
                }
            } header: {
                Text(verbatim: "Notification Center")
            }
        }
        .navigationTitle(Text(verbatim: "Notifications / Alerts"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private let center = NotificationCenter.default

    private var notifications: [(name: Notification.Name, userInfo: [String: Any])] {
        [
            (
                name: .serverMessage,
                userInfo: [
                    kKeyMessage: String.localizedStringWithFormat(
                        #localize("multi_device_unsupported_protocol_version_alert"),
                        TargetManager.localizedAppName,
                        TargetManager.localizedAppName
                    ),
                ]
            ),
            (
                name: .errorConnectionFailed,
                userInfo: [kKeyMessage: #localize("multi_device_linked_devices_failed_remove_message_2")]
            ),
            (
                name: .errorPublicKeyMismatch,
                userInfo: [:]
            ),
            (
                name: .errorRogueDevice,
                userInfo: [:]
            ),
        ]
    }
}
