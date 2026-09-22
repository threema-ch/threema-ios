import Foundation
import libthreemaSwift

extension BallotEntity {
    func update(with poll: LibthreemaPoll) throws {
        guard let state = BallotState(rawValue: Int(poll.state.rawValue)) else {
            throw MappingError.ballotState
        }
        guard let assessmentType = BallotAssessmentType(rawValue: Int(poll.answerType.rawValue)) else {
            throw MappingError.ballotAssessmentType
        }
        guard let type = BallotType(rawValue: Int(poll.announceType.rawValue)) else {
            throw MappingError.ballotType
        }
        guard let displayMode = BallotDisplayMode(rawValue: Int(poll.displayMode.rawValue)) else {
            throw MappingError.ballotDisplayMode
        }

        creatorID = poll.creatorIdentity
        createDate = poll.createdAt.date
        modifyDate = poll.createdAt.date
        title = poll.description
        self.state = state.rawValue as NSNumber
        self.assessmentType = assessmentType.rawValue as NSNumber
        self.type = type.rawValue as NSNumber
        self.displayMode = displayMode.rawValue as NSNumber
    }
}
