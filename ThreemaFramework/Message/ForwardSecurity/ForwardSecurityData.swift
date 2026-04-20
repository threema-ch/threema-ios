import Foundation
import ThreemaEssentials
import ThreemaProtocols

@objc class ForwardSecurityData: NSObject {
    let sessionID: DHSessionID
    
    init(sessionID: DHSessionID) {
        self.sessionID = sessionID
    }
    
    @objc static func fromProtobuf(rawProtobufMessage: Data) throws -> ForwardSecurityData {
        let protobufMessage = try CspE2eFs_Envelope(serializedData: rawProtobufMessage)
        let sessionID = try DHSessionID(value: protobufMessage.sessionID)
        
        switch protobufMessage.content! {
        case let .init_p(initv):
            return try ForwardSecurityDataInit(
                sessionID: sessionID,
                versionRange: initv.supportedVersion,
                ephemeralPublicKey: initv.fssk
            )
            
        case let .accept(accept):
            return try ForwardSecurityDataAccept(
                sessionID: sessionID,
                version: accept.supportedVersion,
                ephemeralPublicKey: accept.fssk
            )
            
        case let .reject(reject):
            let groupIdentity: GroupIdentity? =
                if reject.hasGroupIdentity {
                    try? GroupIdentity(commonGroupIdentity: reject.groupIdentity)
                }
                else {
                    nil
                }
            
            return try ForwardSecurityDataReject(
                sessionID: sessionID,
                messageID: reject.messageID.littleEndianData,
                groupIdentity: groupIdentity,
                cause: reject.cause
            )
            
        case let .encapsulated(message):
            let appliedVersion = CspE2eFs_Version(rawValue: Int(message.appliedVersion)) ??
                .UNRECOGNIZED(Int(message.appliedVersion))
            let offeredVersion = CspE2eFs_Version(rawValue: Int(message.offeredVersion)) ??
                .UNRECOGNIZED(Int(message.offeredVersion))
            
            let groupIdentity: GroupIdentity? =
                if message.hasGroupIdentity {
                    try? GroupIdentity(commonGroupIdentity: message.groupIdentity)
                }
                else {
                    nil
                }
            
            return ForwardSecurityDataMessage(
                sessionID: sessionID,
                type: message.dhType,
                counter: message.counter,
                groupIdentity: groupIdentity,
                offeredVersion: offeredVersion,
                appliedVersion: appliedVersion,
                message: message.encryptedInner
            )
            
        case let .terminate(message):
            return ForwardSecurityDataTerminate(sessionID: sessionID, cause: message.cause)
        }
    }
    
    func toProtobuf() throws -> Data {
        fatalError("Subclasses need to implement the `toProtobuf()` method")
    }
}
