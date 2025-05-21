//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

public class BallotManager: NSObject {
    private let entityManager: EntityManager
    
    @objc init(entityManager: EntityManager) {
        self.entityManager = entityManager
    }
    
    @objc public func choiceResultCount(
        _ ballot: BallotEntity,
        choiceID: NSNumber
    ) -> Int {
        guard let choice = entityManager.entityFetcher.ballotChoice(for: ballot.id, with: choiceID),
              let result = choice.result else {
            DDLogError("[Ballot] [\(ballot.id.hexString)] Could not fetch choice for ballot.")
            return 0
        }
        
        return result.count
    }
    
    @objc public func removeInvalidChoiceResults(
        _ ballot: BallotEntity,
        choiceID: NSNumber,
        participantIDs: [String]
    ) {
        guard let choice = entityManager.entityFetcher.ballotChoice(for: ballot.id, with: choiceID),
              let result = choice.result else {
            DDLogError("[Ballot] [\(ballot.id.hexString)] Could not fetch choice for ballot.")
            return
        }
        
        for ballotResult in result {
            // swiftformat:disable acronyms
            if !participantIDs.contains(ballotResult.participantId) {
                DDLogWarn(
                    "[Ballot] [\(ballot.id.hexString)] Removed vote (\(ballotResult.participantId) from ballot"
                )
                choice.removeResultForIdentity(ballotResult.participantId)
            }
            // swiftformat:enable acronyms
        }
    }
    
    @objc public func updateBallot(
        _ ballot: BallotEntity,
        choiceID: NSNumber,
        with newValue: NSNumber,
        for contactID: String
    ) {
        guard let choice = entityManager.entityFetcher.ballotChoice(for: ballot.id, with: choiceID) else {
            DDLogError("[Ballot] [\(ballot.id.hexString)] Could not fetch choice for ballot.")
            return
        }
               
        updateChoice(choice, with: newValue, for: contactID)
    }
    
    @objc public func updateOwnChoice(_ choice: BallotChoiceEntity, with newValue: NSNumber) {
        updateChoice(choice, with: newValue, for: MyIdentityStore.shared().identity)
    }
    
    @objc public func updateChoice(_ choice: BallotChoiceEntity, with newValue: NSNumber, for contactID: String) {
        
        if let result = choice.getResultForIdentity(contactID) {
            result.value = newValue
            result.modifyDate = Date()
        }
        else {
            guard let newResult = entityManager.entityCreator.ballotResultEntity() else {
                return
            }
            newResult.value = newValue
            // swiftformat:disable:next acronyms
            newResult.participantId = contactID
            
            choice.addToResult(newResult)
        }
        choice.modifyDate = Date()
    }
    
    @objc public func addVoteSystemMessage(
        ballotTitle: String,
        conversation: ConversationEntity,
        contactID: String,
        showIntermediateResults: Bool,
        updatedVote: Bool
    ) {
        
        let voteInfo = VoteInfo(
            ballotTitle: ballotTitle,
            voterID: contactID,
            showIntermediateResults: showIntermediateResults,
            updatedVote: updatedVote
        )
        let json = try? JSONEncoder().encode(voteInfo)
        
        let sysMsg = entityManager.entityCreator.systemMessageEntity(for: conversation)
        let date = Date()
        sysMsg?.type = NSNumber(integerLiteral: updatedVote ? kSystemMessageVoteUpdated : kSystemMessageVote)
        sysMsg?.arg = json
        sysMsg?.date = date
        sysMsg?.remoteSentDate = date
        
        // We intentionally do not save the changes in here. They get saved with the ballot after the last step of
        // decoding.
    }
}
