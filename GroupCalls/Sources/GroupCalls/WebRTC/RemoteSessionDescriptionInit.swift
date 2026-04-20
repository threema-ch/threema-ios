import Foundation

struct RemoteSessionDescriptionInit: Sendable {
    let parameters: SessionParameters
    let remoteParticipants: [ParticipantID]
}
