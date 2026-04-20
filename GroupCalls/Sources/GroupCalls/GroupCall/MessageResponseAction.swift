import Foundation
import ThreemaProtocols

enum MessageResponseAction {
    case none
    case dropPendingParticipant(ParticipantID)
    
    case epHelloAndAuth(PendingRemoteParticipant, (Data, Data))
    case sendAuth(PendingRemoteParticipant, Data)
    case handshakeCompleted(JoinedRemoteParticipant)
    
    case participantToSFU(Groupcall_ParticipantToSfu.Envelope, JoinedRemoteParticipant, ParticipantStateChange)
    case participantToParticipant(RemoteParticipant, Data)
    
    case muteStateChanged(JoinedRemoteParticipant, ParticipantStateChange)
    case rekeyReceived(JoinedRemoteParticipant, MediaKeys)
}
