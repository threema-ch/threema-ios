import Foundation
import WebRTC

actor TransceiverMap<Transceiver: RTCRtpTransceiverProtocol> {
    var local = [SdpKind: Transceiver]()
    var remote = [ParticipantID: Transceivers<Transceiver>]()
    
    func setLocal(_ local: [SdpKind: Transceiver]) {
        self.local = local
    }
    
    func getLocal(for kind: SdpKind) -> Transceiver? {
        local[kind]
    }
    
    func setRemote(_ participantID: ParticipantID, to transceivers: Transceivers<Transceiver>) {
        remote[participantID] = transceivers
    }
}
