import Foundation
import ThreemaProtocols

class ForwardSecurityDataInit: ForwardSecurityData {
    let ephemeralPublicKey: Data
    let versionRange: CspE2eFs_VersionRange
    
    init(sessionID: DHSessionID, versionRange: CspE2eFs_VersionRange, ephemeralPublicKey: Data) throws {
        if ephemeralPublicKey.count != kNaClCryptoSymmKeySize {
            throw ForwardSecurityError.invalidPublicKeyLength
        }
        
        self.versionRange = versionRange
        self.ephemeralPublicKey = ephemeralPublicKey
        super.init(sessionID: sessionID)
    }
    
    override func toProtobuf() throws -> Data {
        var pb = CspE2eFs_Envelope()
        pb.sessionID = sessionID.value
        var pbInit = CspE2eFs_Init()
        pbInit.fssk = ephemeralPublicKey
        pbInit.supportedVersion = versionRange
        pb.content = CspE2eFs_Envelope.OneOf_Content.init_p(pbInit)
        return try pb.serializedData()
    }
}
