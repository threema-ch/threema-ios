import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaEssentials

public protocol MultiDeviceManagerProtocol {
    /// Maximum number of linked devices allowed including this device. This is only set if we are logged into the
    /// mediator
    var maximumNumberOfDeviceSlots: Int? { get }
    
    var thisDevice: DeviceInfo { get }
    
    /// Get sorted list of other linked/paired devices
    /// - Returns: List of other linked/paired devices
    /// - Throws: `MultiDeviceManagerError.multiDeviceNotActivated`, `MessageReceiverError`
    func sortedOtherDevices() async throws -> [DeviceInfo]
    
    func otherDevices() -> Promise<[DeviceInfo]>
    
    /// Drop other linked/paired device.
    /// - Parameter device: Linked/paired device that will dropped
    func drop(device: DeviceInfo) async throws
    
    func drop(device: DeviceInfo) -> Promise<Void>
    func disableMultiDevice(runForwardSecurityRefreshSteps: Bool) async throws
    
    /// Disable multi-device if we can ensure that no other device is left in the group
    func disableMultiDeviceIfNeeded()
}

extension MultiDeviceManagerProtocol {
    public func disableMultiDevice(runForwardSecurityRefreshSteps: Bool = true) async throws {
        try await disableMultiDevice(runForwardSecurityRefreshSteps: runForwardSecurityRefreshSteps)
    }
}

public enum MultiDeviceManagerError: Error {
    case multiDeviceNotActivated
}

public final class MultiDeviceManager: MultiDeviceManagerProtocol {
    private let serverConnector: ServerConnectorProtocol
    private let contactStore: ContactStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let taskManager: TaskManagerProtocol
    private let entityManager: EntityManager

    public var maximumNumberOfDeviceSlots: Int? {
        serverConnector.maximumNumberOfDeviceSlots?.intValue
    }
    
    required init(
        serverConnector: ServerConnectorProtocol,
        contactStore: ContactStoreProtocol,
        userSettings: UserSettingsProtocol,
        taskManager: TaskManagerProtocol,
        entityManager: EntityManager
    ) {
        self.serverConnector = serverConnector
        self.contactStore = contactStore
        self.userSettings = userSettings
        self.taskManager = taskManager
        self.entityManager = entityManager
    }

    public convenience init() {
        self.init(
            serverConnector: ServerConnector.shared(),
            contactStore: ContactStore.shared(),
            userSettings: UserSettings.shared(),
            taskManager: TaskManager(),
            entityManager: PersistenceManager(
                appGroupID: AppGroup.groupID(),
                userDefaults: AppGroup.userDefaults(),
                remoteSecretManager: AppLaunchManager.remoteSecretManager
            ).entityManager
        )
    }

    /// Get device info from this device.
    /// - Returns: This device info
    public var thisDevice: DeviceInfo {
        DeviceInfo(
            deviceID: serverConnector.deviceID != nil ? serverConnector.deviceID!.paddedLittleEndian() : 0,
            label: "\(UIDevice().name)",
            lastLoginAt: Date(),
            badge: nil,
            platform: .ios,
            platformDetails: "\(ThreemaUtility.appAndBuildVersionPretty) • \(UIDevice.modelName) "
        )
    }

    public func sortedOtherDevices() async throws -> [DeviceInfo] {
        try await withCheckedThrowingContinuation { continuation in
            otherDevices()
                .done { devices in
                    // Sort devices by label, if label is the same sort by ID
                    // (so the ordering is consistent across refreshes)
                    let sortedDevices = devices.sorted {
                        if $0.label != $1.label {
                            $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
                        }
                        else {
                            $0.deviceID < $1.deviceID
                        }
                    }
                    
                    continuation.resume(returning: sortedDevices)
                }
                .catch { error in
                    continuation.resume(throwing: error)
                }
        }
    }
    
    /// Get other linked/paired devices.
    /// - Returns: List of other linked/paired devices
    @available(*, deprecated, renamed: "sortedOtherDevices", message: "Only used for old code")
    public func otherDevices() -> Promise<[DeviceInfo]> {
        guard let deviceGroupKeys = serverConnector.deviceGroupKeys, let deviceID = serverConnector.deviceID else {
            return Promise { seal in seal.fulfill([DeviceInfo]()) }
        }

        let messageReceiver = MessageReceiver(
            serverConnector: serverConnector,
            userSettings: userSettings,
            mediatorMessageProtocol: MediatorMessageProtocol(deviceGroupKeys: deviceGroupKeys)
        )
        return messageReceiver.requestDevicesInfo(thisDeviceID: deviceID)
    }
    
    public func drop(device: DeviceInfo) async throws {
        try await withCheckedThrowingContinuation { continuation in
            drop(device: device)
                .done {
                    continuation.resume()
                }
                .catch { error in
                    continuation.resume(throwing: error)
                }
        }
    }

    /// Drop other linked/paired device.
    /// - Parameter device: Linked/paired device that will dropped
    @available(*, deprecated, message: "Only used for old code. Use async version otherwise")
    public func drop(device: DeviceInfo) -> Promise<Void> {
        guard let deviceGroupKeys = serverConnector.deviceGroupKeys else {
            return Promise()
        }

        let messageReceiver = MessageReceiver(
            serverConnector: serverConnector,
            userSettings: userSettings,
            mediatorMessageProtocol: MediatorMessageProtocol(deviceGroupKeys: deviceGroupKeys)
        )
        return messageReceiver.requestDropDevice(device: device)
    }
    
    private func drop(devices: [DeviceInfo]) -> Promise<Void> {
        let drops: [Promise<Void>] = devices.map { deviceInfo in
            self.drop(device: deviceInfo)
        }

        return when(fulfilled: drops)
    }
    
    /// Disable multi device and update feature mask
    /// - Parameter runForwardSecurityRefreshSteps: Run refresh steps for all solicitedContactIdentities
    public func disableMultiDevice(runForwardSecurityRefreshSteps: Bool = true) async throws {
        try await withCheckedThrowingContinuation { continuation in
            otherDevices()
                .then { otherDevices -> Promise<Void> in
                    DDLogNotice("Drop other devices")
                    return self.drop(devices: otherDevices)
                }
                .then { () -> Promise<Void> in
                    DDLogNotice("Drop this device")
                    return self.drop(device: self.thisDevice)
                }
                .then { () -> Promise<Void> in
                    DDLogNotice("Deactivate multi device")
                    self.serverConnector.deactivateMultiDevice()
                                                            
                    return Promise()
                }
                .done {
                    continuation.resume()
                }
                .catch { error in
                    DDLogWarn("Disable multi device failed: \(error)")
                    continuation.resume(throwing: error)
                }
        }
        
        // TODO: (SE-199) Remove everything below
        
        do {
            DDLogNotice("Update own feature mask")

            try await FeatureMask.updateLocal()
            
            DDLogNotice("Contact status update start")
            
            let updateTask: Task<Void, Error> = Task {
                try await contactStore.updateStatusForAllContacts(ignoreInterval: true)
            }
            
            // The request time out is 30s thus we wait for 40s for it to complete
            switch try await Task.timeout(updateTask, 40) {
            case .result:
                break
            case let .error(error):
                DDLogError("Contact status update error: \(error ?? "nil")")
            case .timeout:
                DDLogWarn("Contact status update time out")
            }
        }
        catch {
            // We should still try the next steps if this fails and don't report this error back to the caller
            DDLogWarn("Feature mask or contact status update error: \(error)")
        }
        
        DDLogNotice("Reset import status of all contacts")
        // Reset the `contactImportStatus`, as without the MD, we should update a contact from the linked iOS
        // contact.
        await contactStore.resetImportStatusForAllContacts(entityManager: entityManager)
        
        // Run refresh steps for all solicitedContactIdentities.
        // (See _Application Update Steps_ in the Threema Protocols for details.)
        guard runForwardSecurityRefreshSteps else {
            return
        }
        
        DDLogNotice("Fetch solicited contacts")
        let solicitedContactIdentities = await entityManager.perform {
            self.entityManager.entityFetcher.solicitedContactIdentities()
        }
        
        await ForwardSecurityRefreshSteps().run(for: solicitedContactIdentities.map {
            ThreemaIdentity($0)
        })
    }
    
    public func disableMultiDeviceIfNeeded() {
        guard userSettings.enableMultiDevice else {
            return
        }
        
        let task = TaskDefinitionDisableMultiDeviceIfNeeded()
        taskManager.add(taskDefinition: task)
    }
}
