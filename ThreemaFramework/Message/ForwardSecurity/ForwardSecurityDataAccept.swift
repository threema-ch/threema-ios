import Foundation
import ThreemaProtocols

class ForwardSecurityDataAccept: ForwardSecurityData {
    let ephemeralPublicKey: Data
    let version: CspE2eFs_VersionRange
    
    init(sessionID: DHSessionID, version: CspE2eFs_VersionRange, ephemeralPublicKey: Data) throws {
        if ephemeralPublicKey.count != kNaClCryptoSymmKeySize {
            throw ForwardSecurityError.invalidPublicKeyLength
        }
        self.ephemeralPublicKey = ephemeralPublicKey
        self.version = version
        super.init(sessionID: sessionID)
    }
    
    override func toProtobuf() throws -> Data {
        var pb = CspE2eFs_Envelope()
        pb.sessionID = sessionID.value
        var pbAccept = CspE2eFs_Accept()
        pbAccept.fssk = ephemeralPublicKey
        pbAccept.supportedVersion = version
        pb.content = CspE2eFs_Envelope.OneOf_Content.accept(pbAccept)
        return try pb.serializedData()
    }
}
