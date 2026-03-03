//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
