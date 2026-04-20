import Foundation
import ThreemaEssentials
import ThreemaProtocols

class ForwardSecurityDataMessage: ForwardSecurityData {
    let type: CspE2eFs_Encapsulated.DHType
    let counter: UInt64
    let groupIdentity: GroupIdentity?
    let offeredVersion: CspE2eFs_Version
    let appliedVersion: CspE2eFs_Version
    let message: Data
        
    init(
        sessionID: DHSessionID,
        type: CspE2eFs_Encapsulated.DHType,
        counter: UInt64,
        groupIdentity: GroupIdentity?,
        offeredVersion: CspE2eFs_Version,
        appliedVersion: CspE2eFs_Version,
        message: Data
    ) {
        self.type = type
        self.offeredVersion = offeredVersion
        self.appliedVersion = appliedVersion
        self.counter = counter
        self.message = message
        self.groupIdentity = groupIdentity
        super.init(sessionID: sessionID)
    }
    
    override func toProtobuf() throws -> Data {
        let envelope = CspE2eFs_Envelope.with {
            $0.sessionID = sessionID.value
            $0.encapsulated = CspE2eFs_Encapsulated.with {
                $0.dhType = type
                $0.counter = counter
                $0.offeredVersion = UInt32(offeredVersion.rawValue)
                $0.appliedVersion = UInt32(appliedVersion.rawValue)
                if let groupIdentity {
                    $0.groupIdentity = groupIdentity.asCommonGroupIdentity
                }
                $0.encryptedInner = message
            }
        }
        
        return try envelope.serializedData()
    }
}
