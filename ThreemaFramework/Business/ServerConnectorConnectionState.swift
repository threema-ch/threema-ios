import CocoaLumberjackSwift
import Foundation
import os

/// Managed connection state chat and mediator server.
final class ServerConnectorConnectionState: NSObject {

    private let userSettings: UserSettingsProtocol
    private let connectionStateDelegate: ConnectionStateDelegate

    private enum ServerConnection {
        case any
        case chat
        case mediator
    }

    private var connectionStateChatServer: ConnectionState
    private var connectionStateMediatorServer: ConnectionState

    /// Own lock, because `disconnectCondition` is held while the delegates are called and they may read this
    private let lastConnectionStateChange = OSAllocatedUnfairLock(initialState: Date.now)

    private let disconnectCondition: NSCondition

    @objc init(userSettings: UserSettingsProtocol, connectionStateDelegate: ConnectionStateDelegate) {
        self.userSettings = userSettings
        self.connectionStateDelegate = connectionStateDelegate

        self.connectionStateChatServer = .disconnected
        self.connectionStateMediatorServer = .disconnected
        self.disconnectCondition = NSCondition()
    }

    /// A `connecting` or `connected` state that is not left within this time is assumed to be stuck
    private static let stuckConnectionStateTimeout: TimeInterval = 40

    /// Is the current connection state stuck?
    ///
    /// The socket does not always report back and the state then stays the same forever. `disconnected` and `loggedIn`
    /// are final states and never expire (see `ServerConnector._connect`).
    @objc var isStateExpired: Bool {
        let timeout: TimeInterval? =
            switch connectionState {
            case .disconnecting: TimeInterval(kDisconnectTimeout)
            case .connecting, .connected: Self.stuckConnectionStateTimeout
            case .disconnected, .loggedIn: nil
            }

        guard let timeout else {
            return false
        }

        let secondsInState = -lastConnectionStateChange.withLock { $0 }.timeIntervalSinceNow
        guard secondsInState >= timeout else {
            return false
        }

        DDLogWarn(
            "Connection state is \(nameFor(connectionState: connectionState)) since \(Int(secondsInState)) seconds"
        )
        return true
    }

    /// Representing connection state for chat and mediator server.
    /// - Returns: Connection State
    @objc var connectionState: ConnectionState {
        if !userSettings.enableMultiDevice {
            connectionStateChatServer
        }
        else {
            if connectionStateChatServer == .loggedIn && connectionStateMediatorServer == .loggedIn {
                .loggedIn
            }
            else if connectionStateChatServer == .connecting || connectionStateMediatorServer == .connecting {
                .connecting
            }
            else if connectionStateChatServer == .connected || connectionStateMediatorServer == .connected {
                .connected
            }
            else if connectionStateChatServer == .disconnecting || connectionStateMediatorServer == .disconnecting {
                .disconnecting
            }
            else {
                .disconnected
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
        // Note: it's not guaranteed that the state is actually disconnected at this point, but it's good enough for our
        // purposes
        disconnectCondition.unlock()
    }

    @objc func nameFor(connectionState state: ConnectionState) -> String {
        switch state {
        case .connected: "connected"
        case .connecting: "connecting"
        case .disconnected: "disconnected"
        case .disconnecting: "disconnecting"
        case .loggedIn: "loggedIn"
        }
    }

    private func changeConnectionState(server: ServerConnection, value: ConnectionState) {
        disconnectCondition.lock()

        lastConnectionStateChange.withLock { $0 = .now }

        if server == .any || server == .chat {
            connectionStateChatServer = value
        }
        if userSettings.enableMultiDevice, server == .any || server == .mediator {
            connectionStateMediatorServer = value
        }

        DDLogNotice("Server connection state changed to \(nameFor(connectionState: connectionState))")
        connectionStateDelegate.changed(connectionState: connectionState)

        if connectionState == .disconnected {
            // Release wait on condition
            disconnectCondition.broadcast()
        }
        disconnectCondition.unlock()
    }
}
