import Foundation
import RemoteSecretProtocol
import ThreemaEssentials

public final class RemoteSecretManagerMock: RemoteSecretManagerProtocol, @unchecked Sendable {
    
    public let crypto: any RemoteSecretCryptoProtocol
    
    @Atomic
    public private(set) var isRemoteSecretEnabled: Bool
    
    @Atomic
    public private(set) var checkValidityCalls = 0
    
    @Atomic
    public private(set) var stopMonitoringCalls = 0
    
    public init(
        isRemoteSecretEnabled: Bool = false,
        crypto: any RemoteSecretCryptoProtocol = RemoteSecretCryptoMock()
    ) {
        self.isRemoteSecretEnabled = isRemoteSecretEnabled
        self.crypto = crypto
    }
    
    public func checkValidity() {
        $checkValidityCalls.increment()
    }
    
    public func stopMonitoring() async {
        $stopMonitoringCalls.increment()
    }
    
    // MARK: - Helpers
    
    public func resetCalls() {
        checkValidityCalls = 0
    }
}
