//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaEssentials

/// Coordinates the access to the shared resource (at this time only used for the connection to the server)
/// of message processing between the App, Notification Extension and Share Extension.
/// This should prevent concurrent message processing of several processes.
final class ProcessCoordinator: NSObject {

    private let notificationCenter = DarwinNotificationCenter.shared

    @objc public enum AccessState: Int, CaseIterable, CustomStringConvertible {
        /// Process doesn't access shared resource
        case unused = 0

        /// Process requested access to shared resource
        case requested

        /// Process accesses shared resource
        case using

        /// Process will release shared resource access
        case willRelease

        var description: String {
            switch self {
            case .unused: "unused"
            case .requested: "requested"
            case .using: "using"
            case .willRelease: "willRelease"
            }
        }
    }

    enum ProcessStateHandoverError: Error {
        case triesReached, noAnswer
    }

    // Dispatch queue to sync (serialize) request access calls
    private let startRequestQueue = DispatchQueue(
        label: "ch.threema.ProcessStateHandover.startRequestQueue",
        qos: .userInitiated
    )

    private var pollingSemaphore: DispatchSemaphore?
    private var pollingStopped = false
    private let pollingInMilliseconds = 70

    // Dispatch queue to sync member variables `pollingSemaphore` and `pollingStopped`,
    // note that the polling is running in his own background thread
    private let pollingQueue = DispatchQueue(
        label: "ch.threema.ProcessStateHandover.pollingQueue",
        qos: .userInteractive,
        target: .global()
    )

    // Dispatch queue to sync access to the member variable `state` and `receivedMessageAfterRequest`
    private let updateStateQueue = DispatchQueue(label: "ch.threema.ProcessStateHandover.updateStateQueue")
    private var state: AccessState = .unused
    private var receivedMessageAfterRequest = false

    private let myAppType: AppGroupType
    private weak var serverConnector: ServerConnectorProtocol?
    private let userSettings: UserSettingsProtocol

    private var notificationsToObserve: [DarwinNotificationName] = []

    private var debugLastIncomingState: AccessState?

    required init(
        myAppType: AppGroupType,
        state: AccessState,
        serverConnector: ServerConnectorProtocol,
        userSettings: UserSettingsProtocol
    ) {
        self.myAppType = myAppType
        self.state = state
        self.serverConnector = serverConnector
        self.userSettings = userSettings

        super.init()

        initCommunication()
    }

    @objc convenience init(serverConnector: ServerConnectorProtocol, userSettings: UserSettingsProtocol) {
        self.init(
            myAppType: AppGroup.getCurrentType(),
            state: .unused,
            serverConnector: serverConnector,
            userSettings: userSettings
        )
    }

    deinit {
        for notification in notificationsToObserve {
            notificationCenter.removeObserver(name: notification)
        }

        serverConnector?.unregisterConnectionStateDelegate(delegate: self)
    }

    @available(swift, obsoleted: 1.0, renamed: "AccessState.description", message: "Only use from Objective-C")
    @objc static func nameFor(accessState state: AccessState) -> String {
        state.description
    }

    /// Request access to connecting to chat/mediator server.
    ///
    /// - Parameter pollingTimeout: If the timeout (milliseconds) reached
    ///  then the state will changed to `AccessState.using`.
    ///  If another process is running, the timeout should be higher than 700 ms.
    ///  This is because if the process is busy, the IPC message probably cannot be sent immediately.
    ///
    /// - Returns: Result as state
    @objc func requestAccess(pollingTimeout: Int) async -> AccessState {
        await withCheckedContinuation { continuation in
            startRequestQueue.async {
                guard self.serverConnector?.connectionState != .loggedIn else {
                    DDLogNotice("[Darwin] Already logged in")
                    continuation.resume(returning: .using)
                    return
                }

                continuation.resume(returning: self.requestAccess(timeout: pollingTimeout))
            }
        }
    }

    private func requestAccess(timeout: Int) -> AccessState {
        pollingQueue.sync {
            self.pollingSemaphore = DispatchSemaphore(value: 0)
            self.pollingStopped = false
        }

        updateStateQueue.sync {
            self.receivedMessageAfterRequest = false
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.pollingRequested()
        }

        let result = pollingSemaphore?.wait(timeout: .now() + .milliseconds(timeout))

        pollingQueue.sync {
            self.pollingStopped = true
            self.pollingSemaphore = nil
        }

        if result == .timedOut {
            DDLogWarn("[Darwin] No answer to request access")

            updateStateQueue.sync {
                if !self.receivedMessageAfterRequest {
                    self.update(newState: .using)
                }
            }
        }

        return state
    }

    // MARK: Private functions

    private func initCommunication() {
        serverConnector?.registerConnectionStateDelegate(delegate: self)

        /// Process received IPC message
        /// - Parameter state: IPC message type
        func processIPCMessage(_ state: AccessState, from appType: AppGroupType) {
            updateStateQueue.async {
                if self.debugLastIncomingState != state {
                    self.debugLastIncomingState = state
                    DDLogInfo(
                        "[Darwin] New incoming state: \(state) from: \(AppGroup.name(for: appType)) / actual state: \(self.state)"
                    )
                }
                self.receivedMessageAfterRequest = true

                let newState = self.process(state: state, from: appType)
                self.update(newState: newState)

                self.pollingQueue.sync {
                    self.pollingStopped = true
                    _ = self.pollingSemaphore?.signal()
                }
            }
        }

        // Initializes observers for all other App types in Darwin Notification Center
        for appType in [AppGroupTypeApp, AppGroupTypeShareExtension, AppGroupTypeNotificationExtension] {
            if appType != myAppType {
                for state in AccessState.allCases {
                    let name: DarwinNotificationName = .notificationName(
                        appType: appType,
                        secret: secretPrefix,
                        state: state
                    )

                    notificationCenter.addObserver(name: name) { _ in
                        processIPCMessage(state, from: appType)
                    }

                    notificationsToObserve.append(name)
                }
            }
        }
    }

    private func pollingRequested() {
        func pollingRequestedRecursive() {
            updateStateQueue.sync {
                self.update(newState: .requested, enforcePosting: true)
            }
        }

        DispatchQueue.global(qos: .userInitiated)
            .asyncAfter(deadline: .now() + .milliseconds(pollingInMilliseconds)) {
                let stopped = self.pollingQueue.sync {
                    self.pollingStopped
                }

                if !stopped {
                    pollingRequestedRecursive()

                    self.pollingRequested()
                }
            }
    }

    private func update(newState: AccessState, enforcePosting: Bool = false) {
        var doPost = false
        if state != newState {
            DDLogInfo(
                "[Darwin] Set state from \(state) to \(newState)"
            )
            state = newState
            doPost = true
        }
        if doPost || enforcePosting || state == .using {
            let name: DarwinNotificationName = .notificationName(
                appType: myAppType,
                secret: secretPrefix,
                state: state
            )
            DDLogInfo("[Darwin] Post \(name)")
            notificationCenter.post(name)
        }
    }

    #if DEBUG
        /// Function for unit tests
        func testProcess(
            state receivedState: AccessState,
            from appType: AppGroupType = AppGroupTypeApp
        ) -> AccessState {
            process(state: receivedState, from: appType)
        }
    #endif

    private func process(state receivedState: AccessState, from fromAppType: AppGroupType) -> AccessState {

        guard fromAppType != myAppType else {
            DDLogError(
                "[Darwin] Received state '\(receivedState)' from self app '\(AppGroup.name(for: myAppType))'"
            )
            return state
        }

        let newState: AccessState

        switch receivedState {
        case .unused:
            switch state {
            case .unused: newState = .unused
            case .requested: newState = .using
            case .using: newState = .using
            case .willRelease: newState = .willRelease
            }
        case .requested:
            switch state {
            case .unused: newState = .unused
            case .requested:
                switch myAppType {
                case AppGroupTypeApp: newState = fromAppType == AppGroupTypeShareExtension ? .willRelease : .requested
                case AppGroupTypeShareExtension: newState = .requested
                case AppGroupTypeNotificationExtension: newState = .willRelease
                default:
                    fatalError("Unknown my app type: \(myAppType)")
                }
            case .using:
                switch myAppType {
                case AppGroupTypeApp:
                    if fromAppType == AppGroupTypeShareExtension {
                        // In this case the app and the share extension run at the same time.
                        // This can happen when a file message is shared within the app. Then the app
                        // must disconnect and reconnect with a 2 seconds delay.
                        if serverConnector?.connectionState != .disconnected {
                            serverConnector?.disconnect(initiator: .app)
                            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                                self.serverConnector?.connect(initiator: .app)
                            }
                        }

                        newState = .willRelease
                    }
                    else {
                        newState = .using
                    }
                case AppGroupTypeShareExtension: newState = .using
                case AppGroupTypeNotificationExtension: newState = .willRelease
                default:
                    fatalError("Unknown my app type: \(myAppType)")
                }
            case .willRelease: newState = .willRelease
            }
        case .using:
            switch state {
            case .unused: newState = .unused
            case .requested:
                switch myAppType {
                case AppGroupTypeApp: newState = fromAppType == AppGroupTypeShareExtension ? .willRelease : .requested
                case AppGroupTypeShareExtension: newState = .requested
                case AppGroupTypeNotificationExtension: newState = .willRelease
                default:
                    fatalError("Unknown my app type: \(myAppType)")
                }
            case .using:
                switch myAppType {
                case AppGroupTypeApp: newState = fromAppType == AppGroupTypeShareExtension ? .willRelease : .using
                case AppGroupTypeShareExtension: newState = .using
                case AppGroupTypeNotificationExtension: newState = .willRelease
                default:
                    fatalError("Unknown my app type: \(myAppType)")
                }
            case .willRelease: newState = .willRelease
            }
        case .willRelease:
            switch state {
            case .unused: newState = .unused
            case .requested: newState = .requested
            case .using: newState = .using
            case .willRelease: newState = .willRelease
            }
        }

        return newState
    }

    private var secretPrefix: String {
        if let secret = userSettings.ipcSecretPrefix, !secret.isEmpty {
            return secret.hexString
        }

        guard let secret = BytesUtility.generateRandomBytes(length: 8) else {
            fatalError("Failed to generate random bytes for IPC secret")
        }

        userSettings.ipcSecretPrefix = secret

        return secret.hexString
    }
}

extension DarwinNotificationName {
    private static let appIdentifier = BundleUtil.threemaAppIdentifier() ?? "ch.threema"

    private static func appPrefix(_ appType: AppGroupType) -> String {
        "\(appIdentifier).\(AppGroup.name(for: appType))"
    }

    static func notificationName(
        appType: AppGroupType,
        secret: String,
        state: ProcessCoordinator.AccessState
    ) -> DarwinNotificationName {
        DarwinNotificationName("\(appPrefix(appType))-\(secret)-\(state)")
    }
}

// MARK: - ProcessCoordinator + ConnectionStateDelegate

extension ProcessCoordinator: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        updateStateQueue.async {
            switch state {
            case .connecting, .connected, .loggedIn:
                DDLogNotice("[Darwin] Connected")
                self.update(newState: .using)
            case .disconnecting:
                DDLogNotice("[Darwin] Disconnecting")
                self.update(newState: .willRelease)
            case .disconnected:
                DDLogNotice("[Darwin] Disconnected")
                self.update(newState: .unused)
            }
        }
    }
}
