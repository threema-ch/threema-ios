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

import CocoaLumberjackSwift
import Foundation

public enum DeviceJoinServerConnectionHelperError: Error {
    case couldNotConnect
    case existingActiveWebSessions
}

/// Helper to disconnect and block communication and reenable it again
class DeviceJoinServerConnectionHelper: NSObject {
    
    // MARK: - Private properties
    
    private let businessInjector: BusinessInjectorProtocol

    private var stateDisconnectedContinuation: CheckedContinuation<Void, Never>?
    private var stateLoggedInContinuation: CheckedContinuation<Void, Swift.Error>?

    // MARK: - Lifecycle
    
    init(businessInjector: BusinessInjectorProtocol = BusinessInjector()) {
        self.businessInjector = businessInjector
    }
    
    deinit {
        self.businessInjector.serverConnector.unregisterConnectionStateDelegate(delegate: self)
    }
    
    // MARK: - Disconnect
    
    /// Disconnect from server (waits until connection state has changed to disconnected)
    func disconnect() async {
        await withCheckedContinuation { continuation in
            guard businessInjector.serverConnector.connectionState != .disconnected else {
                return continuation.resume()
            }
            stateDisconnectedContinuation = continuation
            businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)
            self.businessInjector.serverConnector.disconnect(initiator: .app)
        }
    }
    
    // MARK: - Connect
    
    /// Connect to Chat (Mediator) server (waits until connection state has changed to logged in) without receiving any
    /// messages.
    func connectDoNotUnblockIncomingMessages() async throws {
        try await withCheckedThrowingContinuation { continuation in
            guard businessInjector.serverConnector.connectionState != .loggedIn else {
                return continuation.resume()
            }
            stateLoggedInContinuation = continuation
            businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)
            self.businessInjector.serverConnector.connectWaitDoNotUnblockIncomingMessages(initiator: .app)
        }
    }

    /// Connect to Chat (Mediator) server (waits until connection state has changed to logged in).
    func connect() async throws {
        try await withCheckedThrowingContinuation { continuation in
            guard businessInjector.serverConnector.connectionState != .loggedIn else {
                return continuation.resume()
            }
            stateLoggedInContinuation = continuation
            businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)
            self.businessInjector.serverConnector.connectWait(initiator: .app)
        }
    }
}

// MARK: - ConnectionStateDelegate

extension DeviceJoinServerConnectionHelper: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        if state == .loggedIn {
            stateLoggedInContinuation?.resume()
            stateLoggedInContinuation = nil
        }
        else if state == .disconnected {
            stateLoggedInContinuation?.resume(throwing: DeviceJoinServerConnectionHelperError.couldNotConnect)
            stateLoggedInContinuation = nil

            stateDisconnectedContinuation?.resume()
            stateDisconnectedContinuation = nil
        }
    }
}
