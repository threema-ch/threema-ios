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

import CocoaLumberjackSwift
import SwiftUI
import ThreemaMacros

struct DeviceJoinScanQRCodeView: View {
    
    @Binding var showWizard: Bool
    
    @Environment(\.openURL) private var openURL
    
    @ObservedObject var deviceJoinManager: DeviceJoinManager
    
    // MARK: Private state
    
    @State private var urlSafeBase64 = ""
        
    @State private var successfulScanned = false

    @State private var showRetryError = false
    @State private var retryErrorTitle = ""
    @State private var retryErrorMessage = ""
    @State private var showFatalError = false
    @State private var fatalErrorTitle = ""

    @State private var showVerifyEmojiView = false
    
    @AccessibilityFocusState private var isConnectingViewFocused: Bool

    @State private var scannerViewModel: QRCodeScannerViewModel

    init(showWizard: Binding<Bool>, deviceJoinManager: DeviceJoinManager) {
        self._showWizard = showWizard
        let model = QRCodeScannerViewModel(
            mode: .multiDeviceLink,
            audioSessionManager: AudioSessionManager(),
            systemFeedbackManager: SystemFeedbackManager(
                deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                settingsStore: BusinessInjector.ui.settingsStore
            ),
            systemPermissionsManager: SystemPermissionsManager()
        )
        self.scannerViewModel = model
        self.deviceJoinManager = deviceJoinManager
    }

    // MARK: - View

    var body: some View {
        ZStack {
            // `NavigationLink` is needed for programatic navigation
            // If button shapes are enabled `NavigationLink` has an non zero size (that cannot be completely removed
            // by setting the frame, button shape or something similar). Thus we put it behind the other views and hide
            // it, which also disables interaction. This can be resolved if the minimal target is iOS 16 which provides
            // new programatic navigation APIs.
            NavigationLink(
                destination: DeviceJoinVerifyEmojiView(showWizard: $showWizard).environmentObject(deviceJoinManager),
                isActive: $showVerifyEmojiView
            ) {
                EmptyView()
            }
            .hidden()

            QRCodeScannerView(model: scannerViewModel)

            // Allow entering of URL if build with Xcode
            #if targetEnvironment(simulator)
                HStack {
                    TextField(text: $urlSafeBase64) {
                        Text(verbatim: "Join URL")
                    }

                    Button {
                        process(urlSafeBase64: urlSafeBase64)
                    } label: {
                        Text(verbatim: "Connect")
                    }
                }
                .padding(.bottom)
            #endif

            // This is an overlay during establishing the rendezvous connection
            DeviceJoinProgressView(text: #localize("multi_device_join_connecting"))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.thinMaterial)
                .opacity(deviceJoinManager.viewState == .establishRendezvousConnection ? 1 : 0)
                .accessibilityFocused($isConnectingViewFocused)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        // Note: This will also influence all views lower in the navigation stack
        .interactiveDismissDisabled(deviceJoinManager.viewState != .scanQRCode)
        .onChange(of: deviceJoinManager.viewState) { _, nextState in
            switch nextState {
            // We might go back after an error occurred during connection/scanning
            case .scanQRCode:
                break
            case .establishRendezvousConnection:
                isConnectingViewFocused = true
            case .verifyRendezvousConnection:
                showVerifyEmojiView = true
            default:
                break
            }
        }
        .onAppear {
            scannerViewModel.onCancel = {
                deviceJoinManager.deviceJoin.cancel()
                showWizard = false
            }
            scannerViewModel.onCompletion = { result in
                guard case let .multiDeviceLink(urlString) = result else {
                    return
                }
                successfulScanned = true
                process(urlSafeBase64: urlString)
            }
        }
        // Retry error
        .alert(retryErrorTitle, isPresented: $showRetryError) {
            Button("ok") {
                Task {
                    successfulScanned = false
                    try deviceJoinManager.advance(to: .scanQRCode)
                }
            }
        } message: {
            Text(retryErrorMessage)
        }
        // Fatal error
        .alert(fatalErrorTitle, isPresented: $showFatalError) {
            Button("ok") {
                deviceJoinManager.deviceJoin.cancel()
                showWizard = false
            }
        } message: {
            Text(#localize("multi_device_join_fatal_error_message"))
        }
    }

    private func process(urlSafeBase64: String) {
        // Only show connecting state if verification was successful
        do {
            try withAnimation {
                try deviceJoinManager.advance(to: .establishRendezvousConnection)
            }
            connect(to: urlSafeBase64)
        }
        catch {
            DDLogError("Success scan error: \(error)")
            
            fatalErrorTitle = #localize("multi_device_join_unrecoverable_error_title")
            showFatalError = true
        }
    }

    private func connect(to urlSafeBase64: String) {
        Task {
            do {
                let rendezvousPathHash = try await deviceJoinManager.deviceJoin.connect(
                    urlSafeBase64DeviceGroupJoinRequestOffer: urlSafeBase64
                )
                
                try deviceJoinManager.advance(to: .verifyRendezvousConnection(rendezvousPathHash: rendezvousPathHash))
            }
            catch {
                DDLogError("Join connect error: \(error)")
                
                switch error {
                case let rendezvousError as RendezvousProtocol.Error where rendezvousError == .invalidVersion:
                    retryErrorTitle = #localize("multi_device_join_incompatible_version_title")
                    retryErrorMessage = String.localizedStringWithFormat(
                        #localize("multi_device_join_incompatible_version_message"),
                        TargetManager.appName
                    )
                    
                    Task { @MainActor in
                        showRetryError = true
                    }
                
                case let urlError as URLError where urlError.code == .notConnectedToInternet:
                    fatalErrorTitle = #localize("multi_device_join_fatal_no_internet_connection_title")
                    Task { @MainActor in
                        showFatalError = true
                    }
                    
                default:
                    retryErrorTitle = #localize("multi_device_join_new_device_not_found_title")
                    retryErrorMessage = #localize("multi_device_join_new_device_not_found_message")
                    Task { @MainActor in
                        showRetryError = true
                    }
                }
            }
        }
    }
}

struct DeviceJoinScanQRCodeView_Previews: PreviewProvider {
    
    static var deviceJoinManager2: DeviceJoinManager {
        let deviceJoinManager = DeviceJoinManager()
        try! deviceJoinManager.advance(to: .establishRendezvousConnection)
        return deviceJoinManager
    }
    
    static var previews: some View {
        NavigationView {
            DeviceJoinScanQRCodeView(showWizard: .constant(true), deviceJoinManager: DeviceJoinManager())
        }
        
        NavigationView {
            DeviceJoinScanQRCodeView(showWizard: .constant(true), deviceJoinManager: deviceJoinManager2)
        }
    }
}
