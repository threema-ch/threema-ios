import Foundation
import libthreemaSwift

extension BallotResultEntity {
    func update(with vote: PollVote, selected: Bool) {
        value = NSNumber(value: selected)
        createDate = vote.createdAt.date
        modifyDate = vote.modifiedAt?.date
    }
}
