//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import PromiseKit
import ThreemaFramework

class DeviceLinking: NSObject {
    private let businessInjector: BusinessInjectorProtocol

    private let safeStore: SafeStore
    private let safeManager: SafeManager

    private var stateDisconnectedContinuation: CheckedContinuation<Void, Never>?
    private var stateLoggedInContinuation: CheckedContinuation<Void, Error>?

    private var disableMultiDeviceForVersionLessThan5IsLoggedIn: (() -> Void)?

    enum DeviceLinkingError: Error {
        case noDeviceGroupKey, couldNotConnect, timeout
    }

    required init(businessInjector: BusinessInjectorProtocol) {
        self.businessInjector = businessInjector

        let safeConfigManager = SafeConfigManager()
        self.safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: ServerAPIConnector(),
            groupManager: GroupManager()
        )
        self.safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeApiService: SafeApiService()
        )
    }

    @objc
    override convenience init() {
        self.init(businessInjector: BusinessInjector())
    }

    deinit {
        self.businessInjector.serverConnector.unregisterConnectionStateDelegate(delegate: self)
    }

    var threemaSafeServer: String {
        safeStore.getSafeServerToDisplay()
    }

    private(set) var threemaSafePassword: String?

    func generateDeviceGroupKey() throws {
        guard DeviceGroupKeyManager(myIdentityStore: businessInjector.myIdentityStore).create() != nil else {
            throw DeviceLinkingError.noDeviceGroupKey
        }
    }

    /// Upload Threema Safe backup just for Device Linking.
    /// The server will be shown on `self.threemaSafeSever` and the password for backup will be generated.
    /// If backup successfully uploaded the password will shown on `self.threemaSafePassword`.
    func uploadThreemaSafeBackup() async throws {
        let password = SwiftUtils.pseudoRandomStringUpperCaseOnly(length: 16, exclude: ["I", "O"])
        try await safeManager.startBackupForDeviceLinking(password: password)
        threemaSafePassword = password
    }

    func deleteThreemaSafeBackup() {
        guard let password = threemaSafePassword else {
            return
        }
        safeManager.deleteBackupForDeviceLinking(password: password)
    }

    /// Block communications to the services: Threema Calls, MDM, Web, Safe,
    /// Contact-Sync and Chat Server. Disconnect Threema Web and Chat Server connection.
    func blockCommunicationAndDisconnect() async {
        guard !businessInjector.userSettings.blockCommunication else {
            DDLogInfo("Communication is already blocked")
            return
        }

        businessInjector.userSettings.blockCommunication = true

        if let webClientSessions = businessInjector.entityManager.entityFetcher.allActiveWebClientSessions() {
            for session in webClientSessions {
                if let session = session as? WebClientSession {
                    WCSessionManager.shared.stopSession(session)
                }
            }
        }

        await disconnect()
    }

    /// Unblock communications to the services: Threema Calls, MDM, Web, Safe,
    /// Contact-Sync and Chat Server.
    func unblockCommunication() {
        guard businessInjector.userSettings.blockCommunication else {
            DDLogInfo("Communication is not blocked")
            return
        }

        businessInjector.userSettings.blockCommunication = false
    }

    func currentLinkedDevicesCount() async throws -> Int {
        let mm = MultiDeviceManager()

        return try await withCheckedThrowingContinuation { continuation in
            mm.otherDevices()
                .done { otherDevices in
                    continuation.resume(returning: otherDevices.count)
                }
                .catch { error in
                    continuation.resume(throwing: error)
                }
        }
    }

    /// Wait (timeout 900s) until desktop app is linked.
    /// Connection to Mediator server must be established without receiving any messages.
    /// - Parameter currentLinkedDevicesCount: Is null waiting for desktop app otherwise waiting for next linked device desktop or iOS (`currentLinkedDevicesCount + 1`)
    func waitForLinkedDevice(currentLinkedDevicesCount: Int? = nil) async throws {
        let allowedPlatforms: [Platform] = currentLinkedDevicesCount != nil ? [.desktop, .ios] : [.desktop]
        let endTime = Date().addingTimeInterval(900)
        let mm = MultiDeviceManager()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.polling(until: endTime) {
                    mm.otherDevices()
                        .then { otherDevices -> Promise<Void> in
                            if let count = currentLinkedDevicesCount, otherDevices.count <= count {
                                throw MessageReceiverError.responseTimeout
                            }
                            else {
                                if !otherDevices.contains(where: { deviceInfo in
                                    allowedPlatforms.contains(deviceInfo.platform)
                                }) {
                                    throw MessageReceiverError.responseTimeout
                                }
                            }
                            return Promise()
                        }
                }
                .done {
                    continuation.resume()
                }
                .catch { error in
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Polling (every 2 seconds) till `pollingRequest` is fulfilled or until date is reached.
    /// - Parameters:
    ///   - until: Max date/time until polling stops
    ///   - pollingRequest: Is function fulfilled than stops polling otherwise throw MessageReceiverError.responseTimeout
    private func polling<T>(until: Date, _ pollingRequest: @escaping () -> Promise<T>) -> Promise<T> {
        func polling() -> Promise<T> {
            pollingRequest().recover { error -> Promise<T> in
                guard case MessageReceiverError.responseTimeout = error else {
                    throw error
                }
                guard until > Date() else {
                    throw DeviceLinkingError.timeout
                }
                return after(.seconds(2)).then(polling)
            }
        }
        return polling()
    }

    /// Disable multi device if App version less than version 5 and isn't Red or Work Red.
    /// This is needs when the App will downgrade the TestFlight version from 5 to 4.9 (TestFlight or Release).
    @objc func disableMultiDeviceForVersionLessThan5() {
        // Do not disable MD for Xcode build or is red and workRed
        guard ThreemaEnvironment.env() != .xcode else {
            return
        }

        switch ThreemaApp.current {
        case .red, .workRed:
            return
        default:
            guard AppInfo.version.major < 5 || ThreemaEnvironment.env() == .appStore,
                  businessInjector.userSettings.enableMultiDevice else {
                return
            }
        }

        businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)

        if disableMultiDeviceForVersionLessThan5IsLoggedIn == nil {
            disableMultiDeviceForVersionLessThan5IsLoggedIn = {
                guard self.businessInjector.userSettings.enableMultiDevice else {
                    self.disableMultiDeviceForVersionLessThan5IsLoggedIn = nil
                    return
                }

                self.disableMultiDevice()
                    .catch { error in
                        DDLogError("Disable multi device for version less than 5 failed: \(error)")

                        // Disable multi device failed, disconnect and show alert
                        self.businessInjector.serverConnector.disconnect(initiator: .app)

                        let alertText = BundleUtil
                            .localizedString(forKey: "multi_device_linked_devices_failed_remove_message_2")
                        let info = [kKeyMessage: alertText]
                        NotificationCenter.default.post(
                            name: NSNotification.Name(kNotificationErrorConnectionFailed),
                            object: nil,
                            userInfo: info
                        )
                    }
            }
        }
    }

    /// Drop all devices including this device and disable Multi Device
    func disableMultiDevice() -> Promise<Void> {
        businessInjector.multiDeviceManager.otherDevices()
            .then { dropDevices -> Promise<Void> in
                self.drop(items: dropDevices)
            }
            .then { () -> Promise<Bool> in
                Promise { seal in
                    self.drop(items: [self.businessInjector.multiDeviceManager.thisDevice])
                        .done {
                            self.businessInjector.serverConnector.deactivateMultiDevice()

                            // Update feature mask to activate forward secrecy
                            FeatureMask.update()

                            // In this case explicit disconnect is not necessary, because Mediator server makes a disconnect after dropping this device
                            seal.fulfill(false)
                        }
                        .catch { error in
                            seal.reject(error)
                        }
                }
            }
            .then { doDisconnect -> Promise<Void> in
                Promise { seal in
                    Task {
                        // Reconnect to Chat server
                        if doDisconnect {
                            await self.disconnect()
                        }
                        self.unblockCommunication()
                        try? await self.connectWait()

                        seal.fulfill_()
                    }
                }
            }
    }

    func drop(items: [DeviceInfo]) -> Promise<Void> {
        let drops: [Promise<Void>] = items.map { deviceInfo in
            self.businessInjector.multiDeviceManager.drop(device: deviceInfo)
        }

        return when(fulfilled: drops)
    }

    /// Connect to Chat (Mediator) server (waits until connection state has changed to logged in) without receiving any messages.
    func connectWaitDoNotUnblockIncomingMessages() async throws {
        // swiftformat:disable:next all
        return try await withCheckedThrowingContinuation { continuation in
            guard businessInjector.serverConnector.connectionState != .loggedIn else {
                return continuation.resume()
            }
            stateLoggedInContinuation = continuation
            businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)
            self.businessInjector.serverConnector.connectWaitDoNotUnblockIncomingMessages(initiator: .app)
        }
    }

    /// Connect to Chat (Mediator) server (waits until connection state has changed to logged in).
    func connectWait() async throws {
        // swiftformat:disable:next all
        return try await withCheckedThrowingContinuation { continuation in
            guard businessInjector.serverConnector.connectionState != .loggedIn else {
                return continuation.resume()
            }
            stateLoggedInContinuation = continuation
            businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)
            self.businessInjector.serverConnector.connectWait(initiator: .app)
        }
    }

    // Disconnect to server (waits until connection state has changed to disconnected).
    func disconnect() async {
        // swiftformat:disable:next all
        return await withCheckedContinuation { continuation in
            guard businessInjector.serverConnector.connectionState != .disconnected else {
                return continuation.resume()
            }
            stateDisconnectedContinuation = continuation
            businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)
            self.businessInjector.serverConnector.disconnect(initiator: .app)
        }
    }
}

// MARK: - ConnectionStateDelegate

extension DeviceLinking: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        if state == .loggedIn {
            disableMultiDeviceForVersionLessThan5IsLoggedIn?()

            stateLoggedInContinuation?.resume()
            stateLoggedInContinuation = nil
        }
        else if state == .disconnected {
            stateLoggedInContinuation?.resume(throwing: DeviceLinkingError.couldNotConnect)
            stateLoggedInContinuation = nil

            stateDisconnectedContinuation?.resume()
            stateDisconnectedContinuation = nil
        }
    }
}
