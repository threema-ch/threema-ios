import Foundation
import ThreemaEssentials
import WebRTC
@testable import GroupCalls

/// Provides the boilerplate test data that is needed to set up a group call in tests
enum TestDataProvider {
    static func certificate() -> RTCCertificate {
        RTCCertificate(privateKey: "helloWorld", certificate: "helloWorld", fingerprint: "helloWorld")
    }

    static func sessionParameters(participantID: UInt32 = 0) -> SessionParameters {
        SessionParameters(
            participantID: ParticipantID(id: participantID),
            iceParameters: IceParameters(usernameFragment: "", password: ""),
            dtlsParameters: DtlsParameters(fingerprint: []),
            rtpHeaderExtensionIDs: RTPHeaderExtensionIDs()
        )
    }

    static func groupCallBaseState(
        group: GroupCallThreemaGroupModel,
        dependencies: Dependencies,
        gck: Data = Data(repeating: 0x01, count: 32),
        protocolVersion: UInt32 = 0,
        sfuBaseURL: URL = URL(string: "sfu.threema.test")!
    ) throws -> GroupCallBaseState {
        try GroupCallBaseState(
            group: group,
            startedAt: Date(),
            dependencies: dependencies,
            groupCallStartData: GroupCallStartData(
                protocolVersion: protocolVersion,
                gck: gck,
                sfuBaseURL: sfuBaseURL
            )
        )
    }
}
