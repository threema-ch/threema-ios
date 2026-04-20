import Foundation

extension BallotMessageEntity {
    @objc public func updateBallot(_ ballot: BallotEntity) {
        willChangeValue(forKey: "ballot")
        setPrimitiveValue(ballot, forKey: "ballot")
        ballot.managedObjectContext?.refresh(ballot, mergeChanges: true)
        updateBallotState()
        didChangeValue(forKey: "ballot")
    }

    public func isSummaryMessage() -> Bool {
        guard let ballot else {
            return false
        }

        return ballotState?.intValue == BallotEntity.BallotState.closed.rawValue && ballot.state?
            .intValue == BallotEntity.BallotState.closed.rawValue
    }

    private func updateBallotState() {
        guard let state = ballot?.state?.intValue, let stateOfBallot = BallotEntity.BallotState(rawValue: state) else {
            return
        }

        ballotState = NSNumber(integerLiteral: stateOfBallot.rawValue)
    }
}
