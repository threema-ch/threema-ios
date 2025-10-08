//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

struct DeviceJoinView: View {
    
    @EnvironmentObject var settingsStore: SettingsStore
    
    @Binding var showWizard: Bool
    
    // Note: This seems not be be correctly deallocated in some cases even though the view is dismissed.
    // (e.g. when the "No match?" alert is closed in during the emoji verification. Because linking
    // is not often used we don't expect significant memory leaks by that. (IOS-3908)
    @StateObject private var deviceJoinManager = DeviceJoinManager()
    
    // Workaround reactiveness: This should not be changed after the view initially appears
    @State private var isMultiDeviceRegistered = false
    
    var body: some View {
        NavigationView {
            // Inform about incompatibility between PFS and MD if MD isn't enabled at this point
            // This should not be switched after the view initially appears, otherwise the navigation stack is reset
            // Thus we store the setting from the settings store in this local state.
            if isMultiDeviceRegistered {
                DeviceJoinScanQRCodeView(
                    showWizard: $showWizard,
                    deviceJoinManager: deviceJoinManager
                )
            }
            else {
                DeviceJoinPFSInfoView(
                    showWizard: $showWizard,
                    deviceJoinManager: deviceJoinManager
                )
            }
        }
        .onAppear {
            // Part of the workaround of the reactiveness of this setting
            isMultiDeviceRegistered = settingsStore.isMultiDeviceRegistered
        }
    }
}

struct DeviceJoinView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceJoinView(showWizard: .constant(true))
    }
}
