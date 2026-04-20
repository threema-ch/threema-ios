import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct DebugDeviceJoinView: View {
    private enum JoinState {
        case initial
        case connecting
        case connected
        case joining
        case joined
    }

    private struct LogMessage {
        let uuid = UUID()
        let message: String
    }

    @Environment(\.dismiss) private var dismiss

    private let scannerViewModel: QRCodeScannerViewModel
    private var deviceJoin = DeviceJoin(role: .existingDevice)

    @State private var joinState = JoinState.initial {
        didSet {
            logMessages.append(.init(message: "\(joinState)"))
        }
    }

    @State private var deviceJoinURLString = ""

    @State private var isShowingScanner = false

    @State private var logMessages: [LogMessage] = []

    init(model: QRCodeScannerViewModel) {
        self.scannerViewModel = model
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField(text: $deviceJoinURLString) {
                        Text(verbatim: "Join URL")
                    }
                    
                    Button {
                        isShowingScanner = true
                    } label: {
                        Label {
                            Text(verbatim: "Scan")
                        }
                        icon: {
                            Image(systemName: "qrcode")
                        }
                        .labelStyle(IconOnlyLabelStyle())
                    }
                }
                .disabled(joinState != .initial)
                
                if joinState == .initial || joinState == .connecting {
                    Button {
                        Task {
                            joinState = .connecting
                            do {
                                let rendezvousHash = try await deviceJoin.connect(
                                    urlSafeBase64DeviceGroupJoinRequestOffer: deviceJoinURLString
                                )
                                logMessages.append(.init(message: "RPH: \(rendezvousHash.hexString)"))
                                joinState = .connected
                            }
                            catch {
                                joinState = .initial
                                logMessages.append(.init(message: "Error connecting: \(error)"))
                            }
                        }
                    } label: {
                        Text(verbatim: "Connect")
                    }
                    .disabled(joinState != .initial)
                }
                else if joinState == .connected || joinState == .joining {
                    Button {
                        Task {
                            joinState = .joining
                            
                            do {
                                try await deviceJoin.send()
                                
                                joinState = .joined
                            }
                            catch {
                                joinState = .initial
                                logMessages.append(.init(message: "Error sending join data: \(error)"))
                            }
                        }
                    } label: {
                        Text(verbatim: "Send Join Data")
                    }
                    .disabled(joinState != .connected)
                }
            }

            Section {
                ForEach(logMessages, id: \.uuid) { logMessage in
                    Text(logMessage.message)
                }
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            NavigationStack {
                QRCodeScannerView(model: scannerViewModel)
            }
        }
        .navigationTitle(Text(verbatim: "Debug Device Join"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Label(#localize("cancel"), systemImage: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            configureScanner()
        }
    }

    // MARK: - Helpers

    private func configureScanner() {
        scannerViewModel.onCancel = { [weak scannerViewModel] in
            isShowingScanner = false
            scannerViewModel?.onCancel = nil // avoid memory leaks
            scannerViewModel?.onCompletion = nil
        }
        scannerViewModel.onCompletion = { [weak scannerViewModel] result in
            if case let .multiDeviceLink(url) = result {
                deviceJoinURLString = url
                isShowingScanner = false
            }
            scannerViewModel?.onCancel = nil
            scannerViewModel?.onCompletion = nil
        }
    }
}

struct DebugDeviceJoinView_Previews: PreviewProvider {
    static var previews: some View {
        DebugDeviceJoinView(
            model: .init(
                mode: .multiDeviceLink,
                audioSessionManager: .null,
                systemFeedbackManager: .null,
                systemPermissionsManager: .alwaysAllows
            )
        )
    }
}
