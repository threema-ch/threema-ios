import Foundation
import Keychain
import RemoteSecretProtocol

/// Container object to prevent exposure of `RemoteSecretManagerProtocol` to Objective-C
@available(*, deprecated, message: "Only use to pass Remote Secret and Keychain Manager through Objective-C")
@objc public final class RemoteSecretAndKeychainObjC: NSObject {
    public let remoteSecretManager: any RemoteSecretManagerProtocol
    public let keychainManager: any KeychainManagerProtocol
    
    public init(remoteSecretManager: any RemoteSecretManagerProtocol, keychainManager: any KeychainManagerProtocol) {
        self.remoteSecretManager = remoteSecretManager
        self.keychainManager = keychainManager
    }
}
