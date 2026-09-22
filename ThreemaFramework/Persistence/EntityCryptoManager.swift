import Foundation
import RemoteSecretProtocol

final class EntityCryptoManager {
    static let shared = EntityCryptoManager()

    private let remoteSecretQueue =
        DispatchQueue(label: "ch.threema.EntityCryptoManager.remoteSecretQueue")
    private var remoteSecretManager: RemoteSecretManagerProtocol?

    // MARK: - Lifecycle
    
    private init() {
        // no-op
    }

    func setRemoteSecretManager(_ value: RemoteSecretManagerProtocol) {
        remoteSecretQueue.sync {
            remoteSecretManager = value
        }
    }

    // MARK: - Encrypt / Decrypt
    
    // MARK: Data

    func encrypt(_ data: Data) -> Data {
        unwrapRemoteSecret().encrypt(data)
    }
    
    func decrypt(_ data: Data) -> Data {
        unwrapRemoteSecret().decrypt(data)
    }

    // MARK: String

    func encrypt(_ string: String) -> Data {
        unwrapRemoteSecret().encrypt(string)
    }
    
    func decrypt(_ data: Data) -> String {
        unwrapRemoteSecret().decrypt(data)
    }
    
    // MARK: Int16

    func encrypt(_ int16: Int16) -> Data {
        unwrapRemoteSecret().encrypt(int16)
    }
    
    func decrypt(_ data: Data) -> Int16 {
        unwrapRemoteSecret().decrypt(data)
    }
    
    // MARK: Int32

    func encrypt(_ int32: Int32) -> Data {
        unwrapRemoteSecret().encrypt(int32)
    }
    
    func decrypt(_ data: Data) -> Int32 {
        unwrapRemoteSecret().decrypt(data)
    }
    
    // MARK: Int64

    func encrypt(_ int64: Int64) -> Data {
        unwrapRemoteSecret().encrypt(int64)
    }
    
    func decrypt(_ data: Data) -> Int64 {
        unwrapRemoteSecret().decrypt(data)
    }
    
    // MARK: Double

    func encrypt(_ double: Double) -> Data {
        unwrapRemoteSecret().encrypt(double)
    }
    
    func decrypt(_ data: Data) -> Double {
        unwrapRemoteSecret().decrypt(data)
    }
    
    // MARK: Float
    
    func encrypt(_ float: Float) -> Data {
        unwrapRemoteSecret().encrypt(float)
    }
    
    func decrypt(_ data: Data) -> Float {
        unwrapRemoteSecret().decrypt(data)
    }
    
    // MARK: Date

    func encrypt(_ date: Date) -> Data {
        unwrapRemoteSecret().encrypt(date)
    }
    
    func decrypt(_ data: Data) -> Date {
        unwrapRemoteSecret().decrypt(data)
    }
    
    // MARK: Bool

    func encrypt(_ bool: Bool) -> Data {
        unwrapRemoteSecret().encrypt(bool)
    }
    
    func decrypt(_ data: Data) -> Bool? {
        unwrapRemoteSecret().decrypt(data)
    }
    
    // MARK: - Private functions
    
    private func unwrapRemoteSecret() -> RemoteSecretCryptoProtocol {
        remoteSecretQueue.sync {
            guard let remoteSecretManager else {
                fatalError("Remote Secret Manager is not initialized")
            }
            guard remoteSecretManager.isRemoteSecretEnabled else {
                fatalError("No encrypted database model is used")
            }
            return remoteSecretManager.crypto
        }
    }
}
