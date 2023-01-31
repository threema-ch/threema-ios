//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

/// Managed connection state chat and mediator server.
class ServerConnectorConnectionState: NSObject {

    private let userSettings: UserSettingsProtocol
    private let connectionStateDelegate: ConnectionStateDelegate

    private enum ServerConnection {
        case any
        case chat
        case mediator
    }

    private var connectionStateChatServer: ConnectionState
    private var connectionStateMediatorServer: ConnectionState

    private let disconnectCondition: NSCondition

    @objc init(userSettings: UserSettingsProtocol, connectionStateDelegate: ConnectionStateDelegate) {
        self.userSettings = userSettings
        self.connectionStateDelegate = connectionStateDelegate

        self.connectionStateChatServer = .disconnected
        self.connectionStateMediatorServer = .disconnected
        self.disconnectCondition = NSCondition()
    }

    /// Representing connection state for chat and mediator server.
    /// - Returns: Connection State
    @objc var connectionState: ConnectionState {
        if !userSettings.enableMultiDevice {
            return connectionStateChatServer
        }
        else {
            if connectionStateChatServer == .loggedIn && connectionStateMediatorServer == .loggedIn {
                return .loggedIn
            }
            else if connectionStateChatServer == .connecting || connectionStateMediatorServer == .connecting {
                return .connecting
            }
            else if connectionStateChatServer == .connected || connectionStateMediatorServer == .connected {
                return .connected
            }
            else if connectionStateChatServer == .disconnecting || connectionStateMediatorServer == .disconnecting {
                return .disconnecting
            }
            else {
                return .disconnected
            }
        }
    }

    @objc func connecting() {
        changeConnectionState(server: .any, value: .connecting)
    }

    @objc func connected() {
        changeConnectionState(server: .any, value: .connected)
    }

    @objc func disconnecting() {
        changeConnectionState(server: .any, value: .disconnecting)
    }

    @objc func disconnected() {
        changeConnectionState(server: .any, value: .disconnected)
    }

    @objc func loggedInChatServer() {
        changeConnectionState(server: .chat, value: .loggedIn)
    }

    @objc func loggedInMediatorServer() {
        changeConnectionState(server: .mediator, value: .loggedIn)
    }

    /// Wait (max. 3s) for state disconnected.
    @objc func waitForStateDisconnected() {
        disconnectCondition.lock()
        if connectionState != .disconnected {
            disconnectCondition.wait(until: Date(timeIntervalSinceNow: TimeInterval(Int(kDisconnectTimeout))))
        }
        // Note: it's not guaranteed that the state is actually disconnected at this point, but it's good enough for our purposes
        disconnectCondition.unlock()
    }

    @objc func nameFor(connectionState state: ConnectionState) -> String {
        switch state {
        case .connected: return "connected"
        case .connecting: return "connecting"
        case .disconnected: return "disconnected"
        case .disconnecting: return "disconnecting"
        case .loggedIn: return "loggedIn"
        }
    }

    private func changeConnectionState(server: ServerConnection, value: ConnectionState) {
        disconnectCondition.lock()
        let state = connectionState
        if server == .any || server == .chat {
            connectionStateChatServer = value
        }
        if userSettings.enableMultiDevice, server == .any || server == .mediator {
            connectionStateMediatorServer = value
        }
        if state != connectionState {
            DDLogNotice("Server connection state changed to \(nameFor(connectionState: connectionState))")
            connectionStateDelegate.changed(connectionState: connectionState)
        }
        if connectionState == .disconnected {
            // Release wait on condition
            disconnectCondition.broadcast()
        }
        disconnectCondition.unlock()
    }
}
