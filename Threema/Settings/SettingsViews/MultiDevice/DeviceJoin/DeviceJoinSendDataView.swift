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

import CocoaLumberjackSwift
import SwiftUI
import ThreemaMacros

struct DeviceJoinSendDataView: View {
    
    @Binding var showWizard: Bool

    @EnvironmentObject private var deviceJoinManager: DeviceJoinManager

    @State private var sendingText = #localize("multi_device_join_sending_data")
    
    @State private var showSendingError = false
    @State private var showThreemaWebError = false

    @State private var showSuccessView = false

    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                // The `ZStack` and `NavigationLink` is needed for programatic navigation
                // If button shapes are enabled `NavigationLink` has an non zero size (that cannot be completely removed
                // by setting the frame, button shape or something similar). Thus we put it behind the progress view and
                // hide it, which also disables interaction. This can be resolved if the minimal target is iOS 16 which
                // provides new programatic navigation APIs.
                NavigationLink(
                    destination: DeviceJoinSuccessView(showWizard: $showWizard),
                    isActive: $showSuccessView
                ) {
                    EmptyView()
                }
                .hidden()
                
                DeviceJoinProgressView(text: sendingText)
            }

            Spacer()
        }
        .padding(24)
        .navigationBarBackButtonHidden()
        // If this is set higher in the navigation stack this will be overridden by it
        .interactiveDismissDisabled()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .cancel) {
                    deviceJoinManager.deviceJoin.cancel()
                    showWizard = false
                } label: {
                    Label(#localize("cancel"), systemImage: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            
            sendData()
            
            // Workaround if somebody waits looking at their device.
            // This should be replaced by a accurate progress report from the sending function: IOS-3909
            Task { @MainActor in
                try await Task.sleep(seconds: 5)
                withAnimation {
                    sendingText = #localize("multi_device_join_sending_continue_on_new_device")
                }
                
                try await Task.sleep(seconds: 10)
                withAnimation {
                    sendingText = #localize("multi_device_join_sending_wait")
                }
            }
        }
        .onChange(of: deviceJoinManager.viewState) { nextState in
            switch nextState {
            case .completed:
                showSuccessView = true
            default:
                break
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .alert(
            #localize("multi_device_join_failed_to_send_data_title"),
            isPresented: $showSendingError
        ) {
            Button("ok") {
                showWizard = false
            }
        } message: {
            Text(#localize("multi_device_join_fatal_error_message"))
        }
        .alert(
            #localize("multi_device_join_failed_threema_web_title"),
            isPresented: $showThreemaWebError
        ) {
            Button("ok") {
                showWizard = false
            }
        } message: {
            Text(#localize("multi_device_join_failed_threema_web_message"))
        }
    }
    
    private func sendData() {
        Task {
            // Disconnect all Threema Web Sessions
            if let webClientSessions = BusinessInjector().entityManager.entityFetcher.allActiveWebClientSessions() {
                for session in webClientSessions {
                    if let session = session as? WebClientSessionEntity {
                        WCSessionManager.shared.stopSession(session)
                    }
                }
            }
            
            // Run join
            do {
                try await deviceJoinManager.deviceJoin.send()
                Task { @MainActor in
                    try deviceJoinManager.advance(to: .completed)
                }
            }
            catch DeviceJoinServerConnectionHelperError.existingActiveWebSessions {
                DDLogError("Failed to send data: DeviceJoinServerConnectionHelperError.existingActiveWebSessions")

                showThreemaWebError = true
            }
            catch {
                DDLogError("Failed to send data: \(error)")
                
                showSendingError = true
            }
        }
    }
}
