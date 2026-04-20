import CocoaLumberjackSwift
import SwiftUI
import ThreemaMacros

struct DeviceJoinSendDataView: View {
    @ObservedObject var deviceJoinManager: DeviceJoinManager
    @Binding var showWizard: Bool
    @Binding var path: NavigationPath
    @State private var sendingText = #localize("multi_device_join_sending_data")
    @State private var showSendingError = false
    @State private var showThreemaWebError = false

    var body: some View {
        VStack {
            Spacer()
            DeviceJoinProgressView(text: sendingText)
            Spacer()
        }
        .padding(24)
        .navigationBarBackButtonHidden()
        // If this is set higher in the navigation stack this will be overridden by it
        .interactiveDismissDisabled()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                XMarkCancelButton {
                    deviceJoinManager.deviceJoin.cancel()
                    showWizard = false
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
        .onChange(of: deviceJoinManager.viewState) {
            if case .completed = deviceJoinManager.viewState {
                path.append(DeviceJoinRoute.success)
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
            if let webClientSessions = BusinessInjector.ui.entityManager.entityFetcher
                .activeWebClientSessionEntities() {
                for session in webClientSessions {
                    WCSessionManager.shared.stopSession(session)
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
