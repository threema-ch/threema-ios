//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ThreemaMacros

extension BallotMessageEntity {
    override public func additionalExportInfo() -> String? {
        guard let ballot else {
            return nil
        }
        var info = "\(#localize("ballot")): \(ballot.title ?? "")"
        
        for choice in ballot.choicesSortedByOrder {
            info += "- \(choice.name ?? "")\n"
        }
        return info
    }
    
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
