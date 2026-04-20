import Foundation
import ThreemaEssentials

@GlobalGroupCallActor
protocol Participant {
    nonisolated var participantID: ParticipantID { get }
}
