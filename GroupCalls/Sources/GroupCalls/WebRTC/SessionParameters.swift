import Foundation

struct SessionParameters {
    let participantID: ParticipantID
    let iceParameters: IceParameters
    let dtlsParameters: DtlsParameters
    let rtpHeaderExtensionIDs: RTPHeaderExtensionIDs
}
