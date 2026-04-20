import CocoaLumberjackSwift
import Foundation
import Keychain
import ThreemaEssentials

protocol DeviceGroupKeyManagerProtocol {
    var dgk: Data? { get }
    func load() -> Data?
    /// This function is static, since we must be able to delete the key in setup
    static func destroy() -> Bool
    func store(dgk: Data) -> Bool
}

public final class DeviceGroupKeyManager: NSObject, DeviceGroupKeyManagerProtocol {
    private let keychainManager: KeychainManagerProtocol

    @objc override public convenience init() {
        self.init(keychainManager: KeychainManager(remoteSecretManager: AppLaunchManager.remoteSecretManager))
    }

    public required init(keychainManager: KeychainManagerProtocol) {
        self.keychainManager = keychainManager
    }

    /// Device Group Key stored in keychain.
    @objc public var dgk: Data? {
        load()
    }

    /// Create new DGK and store it (override) in keychain.
    public func create() -> Data? {
        guard let key = BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceGroupKeyLength) else {
            return nil
        }
        guard store(dgk: key) else {
            return nil
        }
        return key
    }

    /// Load DGK from Keychain
    /// - Returns: DGK or nil if not found
    public func load() -> Data? {
        do {
            return try keychainManager.loadMultiDeviceGroupKey()
        }
        catch {
            DDLogError("Couldn't load device group key from Keychain: \(error)")
            return nil
        }
    }

    /// Destroy DGK from Keychain.
    /// - Returns: True if key founded and destroyed
    @discardableResult @objc public static func destroy() -> Bool {
        do {
            try KeychainManager.deleteMultiDeviceGroupKey()
            return true
        }
        catch {
            DDLogError("Couldn't delete device group key in Keychain: \(error)")
            return false
        }
    }

    /// Store DGK into Keychain.
    /// - Parameter dgk: Device Group Key
    /// - Returns: True DGK stored successfully
    @discardableResult public func store(dgk: Data) -> Bool {
        do {
            try keychainManager.storeMultiDeviceGroupKey(key: dgk)
            return true
        }
        catch {
            DDLogError("Couldn't store device group key in Keychain: \(error)")
            return false
        }
    }
}
