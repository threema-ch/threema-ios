//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import CodeScanner
import SwiftUI

struct DebugDeviceJoinView: View {
    
    private enum JoinState {
        case initial
        case connecting
        case connected
        case joining
        case joined
    }
    
    private var deviceJoin = DeviceJoin(role: .existingDevice)
    @State private var joinState = JoinState.initial {
        didSet {
            logMessages.append(.init(message: "\(joinState)"))
        }
    }
    
    @State private var deviceJoinURLString =
        ""
    
    @State private var isShowingScanner = false
    
    private struct LogMessage {
        let uuid = UUID()
        let message: String
    }
    
    @State private var logMessages: [LogMessage] = []
    
    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Join URL", text: $deviceJoinURLString)
                    
                    Button {
                        isShowingScanner = true
                    } label: {
                        Label("Scan", systemImage: "qrcode")
                            .labelStyle(IconOnlyLabelStyle())
                    }
                }
                .disabled(joinState != .initial)
                
                if joinState == .initial || joinState == .connecting {
                    Button("Connect") {
                        Task {
                            joinState = .connecting
                            do {
                                guard let url = URL(string: deviceJoinURLString) else {
                                    // Just picked a random error
                                    throw CancellationError()
                                }
                                
                                let parsedURL = try URLParser.parse(url: url)
                                guard case let .deviceGroupJoinRequestOffer(urlSafeBase64: base64) = parsedURL else {
                                    // Just picked a random error
                                    throw CancellationError()
                                }
                                
                                let rendezvousHash = try await deviceJoin
                                    .connect(urlSafeBase64DeviceGroupJoinRequestOffer: base64)
                                
                                logMessages.append(.init(message: "RPH: \(rendezvousHash.hexString)"))
                                
                                joinState = .connected
                            }
                            catch {
                                joinState = .initial
                                logMessages.append(.init(message: "Error connecting: \(error)"))
                            }
                        }
                    }
                    .disabled(joinState != .initial)
                }
                else if joinState == .connected || joinState == .joining {
                    Button("Send Join Data") {
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
            CodeScannerView(codeTypes: [.qr], completion: handleScan(result:))
        }
    }
    
    private func handleScan(result: Swift.Result<ScanResult, ScanError>) {
        switch result {
        case let .success(result):
            guard !result.string.isEmpty else {
                logMessages.append(.init(message: "Empty string scanned"))
                return
            }
            
            deviceJoinURLString = result.string
        case let .failure(error):
            logMessages.append(.init(message: "QR code scanning failed: \(error)"))
        }
        
        isShowingScanner = false
    }
}

struct DebugDeviceJoinView_Previews: PreviewProvider {
    static var previews: some View {
        DebugDeviceJoinView()
    }
}
