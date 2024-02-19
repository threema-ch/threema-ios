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
import CodeScanner
import SwiftUI

struct DeviceJoinScanQRCodeView: View {
    
    @Binding var showWizard: Bool
    
    @Environment(\.openURL) private var openURL
    
    @EnvironmentObject private var deviceJoinManager: DeviceJoinManager
    
    // MARK: Private state
    
    @State private var debugDeviceJoinURLString = ""
        
    @State private var successfulScanned = false
    
    @State private var showNoCameraAccessAlert = false
    @State private var showRetryError = false
    @State private var retryErrorTitle = ""
    @State private var retryErrorMessage = ""
    @State private var showFatalError = false
    @State private var fatalErrorTitle = ""

    @State private var showVerifyEmojiView = false
    
    @AccessibilityFocusState private var isConnectingViewFocused: Bool
    
    // MARK: - View
    
    var body: some View {
        ZStack {
            // `NavigationLink` is needed for programatic navigation
            // If button shapes are enabled `NavigationLink` has an non zero size (that cannot be completely removed
            // by setting the frame, button shape or something similar). Thus we put it behind the other views and hide
            // it, which also disables interaction. This can be resolved if the minimal target is iOS 16 which provides
            // new programatic navigation APIs.
            NavigationLink(
                destination: DeviceJoinVerifyEmojiView(showWizard: $showWizard),
                isActive: $showVerifyEmojiView
            ) {
                EmptyView()
            }
            .hidden()
            
            GeometryReader { geometryProxy in
                ScrollView {
                    VStack {
                        
                        DeviceJoinHeaderView(
                            title: "multi_device_join_scan_qr_code_title".localized,
                            description: String.localizedStringWithFormat(
                                "multi_device_join_scan_qr_code_info".localized,
                                ThreemaApp.appName
                            )
                        )
                        
                        Spacer()
                        
                        Group {
                            if !successfulScanned {
                                // This needs to reappear after a scan with an error so it actually scans again
                                CodeScannerView(codeTypes: [.qr]) { result in
                                    Task { @MainActor in
                                        handleScan(result: result)
                                    }
                                }
                                .background(Color.green) // Only needed for preview & simulator
                                .accessibilityElement()
                                .accessibilityLabel(
                                    BundleUtil.localizedString(
                                        forKey: "multi_device_join_scan_qr_code_scanner_view_accessibility_label"
                                    )
                                )
                                .accessibilityHint(String.localizedStringWithFormat(
                                    BundleUtil.localizedString(
                                        forKey: "multi_device_join_scan_qr_code_scanner_view_accessibility_hint"
                                    ),
                                    ThreemaApp.appName
                                ))
                            }
                            else {
                                Color.black
                            }
                        }
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        
                        Spacer()
                        Spacer()
                        
                        // Allow entering of URL if build with Xcode
                        #if targetEnvironment(simulator)
                            HStack {
                                TextField("Join URL", text: $debugDeviceJoinURLString)
                            
                                Button {
                                    connect(to: debugDeviceJoinURLString)
                                } label: {
                                    Text("Connect")
                                }
                            }
                            .padding(.bottom)
                        #endif
                    }
                    .frame(minHeight: geometryProxy.size.height - geometryProxy.safeAreaInsets.bottom)
                    .padding([.horizontal, .bottom], 24)
                }
            }
            
            // This is an overlay during establishing the rendezvous connection
            DeviceJoinProgressView(text: "multi_device_join_connecting".localized)
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
        .onChange(of: deviceJoinManager.viewState) { nextState in
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
        // No camera access
        .alert(
            "alert_no_access_title_camera".localized,
            isPresented: $showNoCameraAccessAlert
        ) {
            Button("alert_no_access_open_settings".localized) {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                    DDLogWarn("Unable to get settings URL")
                    return
                }
                
                openURL(settingsURL)
            }
            
            Button("Cancel", role: .cancel) { // No specific localization is needed
                showWizard = false
            }
        } message: {
            Text("alert_no_access_message_camera".localized)
        }
        // Retry error
        .alert(
            retryErrorTitle,
            isPresented: $showRetryError
        ) {
            Button("OK") {
                Task {
                    successfulScanned = false
                    try deviceJoinManager.advance(to: .scanQRCode)
                }
            }
        } message: {
            Text(retryErrorMessage)
        }
        // Fatal error
        .alert(
            fatalErrorTitle,
            isPresented: $showFatalError
        ) {
            Button("OK") {
                deviceJoinManager.deviceJoin.cancel()
                showWizard = false
            }
        } message: {
            Text("multi_device_join_fatal_error_message".localized)
        }
    }
    
    private func handleScan(result: Swift.Result<ScanResult, ScanError>) {
        switch result {
        case let .success(success):
            successfulScanned = true
            
            // Verify URL
            guard let urlSafeBase64 = verify(qrCodeString: success.string) else {
                DDLogError("Invalid QR Code")
                
                retryErrorTitle = "multi_device_join_unknown_qr_code_title".localized
                retryErrorMessage = String.localizedStringWithFormat(
                    "multi_device_join_unknown_qr_code_message".localized,
                    DeviceJoinManager.downloadURL
                )
                showRetryError = true
                
                return
            }
            
            // Only show connecting state if verification was successful
            do {
                try withAnimation {
                    try deviceJoinManager.advance(to: .establishRendezvousConnection)
                }
                
                connect(to: urlSafeBase64)
            }
            catch {
                DDLogError("Success scan error: \(error)")
                
                fatalErrorTitle = "multi_device_join_unrecoverable_error_title".localized
                showFatalError = true
            }
            
        case .failure(.permissionDenied):
            DDLogError("No camera access when scanning QR Code")
            requestCameraAccess()
            
        case .failure:
            fatalErrorTitle = "multi_device_join_fatal_scanning_qr_code_error_title".localized
            showFatalError = true
            
            DDLogError(fatalErrorTitle)
        }
    }
    
    private func requestCameraAccess() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    Task { @MainActor in
                        showNoCameraAccessAlert = true
                    }
                }
            }
        case .restricted, .denied:
            DDLogError("Restricted or denied camera access")
            showNoCameraAccessAlert = true
        case .authorized:
            // Everything is all right
            break
        @unknown default:
            DDLogError("Unknown default camera authorization status")
            fatalErrorTitle = "multi_device_join_fatal_camera_access_error_title".localized
            showFatalError = true
        }
    }
   
    private func verify(qrCodeString: String) -> String? {
        guard let url = URL(string: qrCodeString) else {
            return nil
        }
        
        let parsedURL: URLParser.URLType
        do {
            parsedURL = try URLParser.parse(url: url)
        }
        catch {
            DDLogError("Error parsing url: \(error)")
            return nil
        }
        
        guard case let .deviceGroupJoinRequestOffer(urlSafeBase64: urlSafeBase64) = parsedURL else {
            return nil
        }
        
        return urlSafeBase64
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
                    retryErrorTitle = "multi_device_join_incompatible_version_title".localized
                    retryErrorMessage = String.localizedStringWithFormat(
                        "multi_device_join_incompatible_version_message".localized,
                        ThreemaApp.appName
                    )
                    
                    Task { @MainActor in
                        showRetryError = true
                    }
                
                case let urlError as URLError where urlError.code == .notConnectedToInternet:
                    fatalErrorTitle = BundleUtil
                        .localizedString(forKey: "multi_device_join_fatal_no_internet_connection_title")
                    Task { @MainActor in
                        showFatalError = true
                    }
                    
                default:
                    retryErrorTitle = "multi_device_join_new_device_not_found_title".localized
                    retryErrorMessage = BundleUtil
                        .localizedString(forKey: "multi_device_join_new_device_not_found_message")
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
            DeviceJoinScanQRCodeView(showWizard: .constant(true))
                .environmentObject(DeviceJoinManager())
        }
        
        NavigationView {
            DeviceJoinScanQRCodeView(showWizard: .constant(true))
                .environmentObject(deviceJoinManager2)
        }
    }
}
