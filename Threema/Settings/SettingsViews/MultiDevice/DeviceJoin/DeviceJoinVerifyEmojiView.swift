//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

struct DeviceJoinVerifyEmojiView: View {

    @Binding var showWizard: Bool
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @EnvironmentObject private var deviceJoinManager: DeviceJoinManager

    @State private var showNoMatchAlert = false
    
    @State private var startSendData = false
    
    var body: some View {
        GeometryReader { geometryProxy in
            ScrollView {
                VStack(alignment: .center) {
                    
                    DeviceJoinHeaderView(
                        title: "multi_device_join_trust_new_device_title".localized,
                        description: "multi_device_join_trust_new_device_info".localized
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
                            
                            Button("multi_device_join_no_match_button".localized) {
                                showNoMatchAlert = true
                            }
                        }
                    }
                    else {
                        // This should never happen
                        VStack {
                            Text(
                                "An unexpected error occurred. Please restart the app on the new device and try again."
                            )
                            .multilineTextAlignment(.center)
                            
                            Button("OK") {
                                deviceJoinManager.deviceJoin.cancel()
                                showWizard = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    Spacer(minLength: 24)
                    
                    ZStack {
                        // The `ZStack` and `NavigationLink` is needed for programatic navigation
                        // If button shapes are enabled `NavigationLink` has an non zero size (that cannot be completely
                        // removed by setting the frame, button shape or something similar). Thus we put it behind the
                        // label and hide it, which also disables interaction. This can be resolved if the minimal
                        // target is iOS 16 which provides new programatic navigation APIs.
                        NavigationLink(
                            destination: DeviceJoinSendDataView(showWizard: $showWizard),
                            isActive: $startSendData
                        ) {
                            EmptyView()
                        }
                        .hidden()
                        
                        Label(
                            String.localizedStringWithFormat(
                                "multi_device_join_sending_info".localized,
                                ThreemaApp.appName
                            ),
                            systemImage: "info.circle"
                        )
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    }
                }
                .padding([.horizontal, .bottom], 24)
                .frame(minHeight: geometryProxy.size.height)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        // If this is set higher in the navigation stack this will be overridden by it
        .interactiveDismissDisabled()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .cancel) {
                    deviceJoinManager.deviceJoin.cancel()
                    showWizard = false
                } label: {
                    Label("Cancel", systemImage: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.secondary)
                }
            }
        }
        .alert("multi_device_join_no_match_title".localized, isPresented: $showNoMatchAlert) {
            Button("ok".localized) {
                deviceJoinManager.deviceJoin.cancel()
                showWizard = false
            }
        } message: {
            Text("multi_device_join_no_match_message".localized)
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
            DeviceJoinVerifyEmojiView(showWizard: .constant(true))
                .environmentObject(deviceJoinManager)
        }
    }
}
