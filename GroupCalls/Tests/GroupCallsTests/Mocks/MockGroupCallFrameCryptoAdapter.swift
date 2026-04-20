import Foundation
import WebRTC

@testable import GroupCalls

final class MockGroupCallFrameCryptoAdapter: GroupCallFrameCryptoAdapterProtocol {
    func attachEncryptor(to transceiver: RTCRtpTransceiver, myParticipantID: GroupCalls.ParticipantID) throws {
        // Noop
    }
    
    func applyMediaKeys(from localParticipant: GroupCalls.LocalParticipant) async throws {
        // Noop
    }
}
