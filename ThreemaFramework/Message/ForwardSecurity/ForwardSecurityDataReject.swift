import Foundation
import ThreemaEssentials
import ThreemaProtocols

class ForwardSecurityDataReject: ForwardSecurityData {
    let messageID: Data
    let groupIdentity: GroupIdentity?
    let cause: CspE2eFs_Reject.Cause
        
    init(
        sessionID: DHSessionID,
        messageID: Data,
        groupIdentity: GroupIdentity?,
        cause: CspE2eFs_Reject.Cause
    ) throws {
        if messageID.count != ThreemaProtocol.messageIDLength {
            throw ForwardSecurityError.invalidMessageIDLength
        }
            
        self.messageID = messageID
        self.groupIdentity = groupIdentity
        self.cause = cause
        
        super.init(sessionID: sessionID)
    }
    
    override func toProtobuf() throws -> Data {
        let envelope = try CspE2eFs_Envelope.with {
            $0.sessionID = sessionID.value
            $0.reject = try CspE2eFs_Reject.with {
                $0.messageID = try messageID.littleEndian()
                if let groupIdentity {
                    $0.groupIdentity = groupIdentity.asCommonGroupIdentity
                }
                $0.cause = cause
            }
        }
        
        return try envelope.serializedData()
    }
}
