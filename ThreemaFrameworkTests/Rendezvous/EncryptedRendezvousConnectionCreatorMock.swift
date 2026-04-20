import Foundation
import ThreemaProtocols
@testable import ThreemaFramework

final class EncryptedRendezvousConnectionCreatorMock: EncryptedRendezvousConnectionCreator {
    
    let encryptedRendezvousConnectionMock: EncryptedRendezvousConnectionMock
    let rendezvousCryptoMock: RendezvousCryptoMock
    
    init(
        encryptedRendezvousConnectionMock: EncryptedRendezvousConnectionMock,
        rendezvousCryptoMock: RendezvousCryptoMock
    ) {
        self.encryptedRendezvousConnectionMock = encryptedRendezvousConnectionMock
        self.rendezvousCryptoMock = rendezvousCryptoMock
    }
    
    func create(
        from rendezvousInit: Rendezvous_RendezvousInit
    ) throws -> (EncryptedRendezvousConnection, RendezvousCrypto) {
        (encryptedRendezvousConnectionMock, rendezvousCryptoMock)
    }
}
