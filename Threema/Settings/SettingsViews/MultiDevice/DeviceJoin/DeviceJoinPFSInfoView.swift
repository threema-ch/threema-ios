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
import ThreemaMacros

struct DeviceJoinPFSInfoView: View {
    
    @Binding var showWizard: Bool
    
    @Environment(\.openURL) private var openURL
    
    @State private var showScanQRCodeView = false
        
    var body: some View {
        VStack {
            ScrollView {
                DeviceJoinHeaderView(
                    title: #localize("settings_list_threema_desktop_title"),
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
            
            ZStack {
                // The `ZStack` and `NavigationLink` is needed for programatic navigation
                // If button shapes are enabled `NavigationLink` has an non zero size (that cannot be completely removed
                // by setting the frame, button shape or something similar). Thus we put it behind the button and hide
                // it, which also disables interaction. This can be resolved if the minimal target is iOS 16 which
                // provides new programatic navigation APIs.
                NavigationLink(
                    destination: DeviceJoinScanQRCodeView(showWizard: $showWizard),
                    isActive: $showScanQRCodeView
                ) {
                    EmptyView()
                }
                .hidden()
                            
                // So far there is not exact button that matches the one used by system apps
                Button {
                    showScanQRCodeView = true
                } label: {
                    Text(#localize("multi_device_new_linked_devices_add_button"))
                        .font(.title3) // This is a little bit too big
                        .bold()
                        .padding(8)
                        .frame(maxWidth: .infinity)
                }
                .padding([.horizontal, .bottom], 24)
                .buttonStyle(.bordered)
                .foregroundColor(.primary)
                .buttonBorderShape(.roundedRectangle(radius: 12))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .cancel) {
                    showWizard = false
                } label: {
                    Label(#localize("cancel"), systemImage: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct DeviceJoinPFSInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DeviceJoinPFSInfoView(showWizard: .constant(true))
        }
    }
}
