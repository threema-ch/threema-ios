import Foundation
import ThreemaProtocols

class ForwardSecurityDataTerminate: ForwardSecurityData {
    let cause: CspE2eFs_Terminate.Cause
    
    init(sessionID: DHSessionID, cause: CspE2eFs_Terminate.Cause) {
        self.cause = cause
        super.init(sessionID: sessionID)
    }
    
    override func toProtobuf() throws -> Data {
        var pb = CspE2eFs_Envelope()
        pb.sessionID = sessionID.value
        var pbTerminate = CspE2eFs_Terminate()
        pbTerminate.cause = cause
        pb.content = CspE2eFs_Envelope.OneOf_Content.terminate(pbTerminate)
        return try pb.serializedData()
    }
}
