import Foundation
@testable import ThreemaFramework

final class RendezvousCryptoMock: RendezvousCrypto {
    
    private(set) var switchedToTransportKeysCalled = 0
    private let switchDataToReturn: Data
    
    init(switchDataToReturn: Data = Data()) {
        self.switchDataToReturn = switchDataToReturn
    }
    
    func encrypt(_ data: Data) throws -> Data {
        data
    }
    
    func decrypt(_ data: Data) throws -> Data {
        data
    }
    
    func switchToTransportKeys(
        localEphemeralTransportKeyPair: NaClCrypto.KeyPair,
        remotePublicEphemeralTransportKey: Data
    ) throws -> Data {
        switchedToTransportKeysCalled += 1
        
        return switchDataToReturn
    }
}
