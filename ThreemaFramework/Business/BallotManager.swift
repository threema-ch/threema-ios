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
import ThreemaEssentials
import ThreemaMacros

public class BallotManager: NSObject {
    private let entityManager: EntityManager
    
    @objc public init(entityManager: EntityManager) {
        self.entityManager = entityManager
    }
    
    @objc public func create(
        with title: String,
        choices: [String],
        type: BallotEntity.BallotType,
        assessmentType: BallotEntity.BallotAssessmentType,
        conversation: NSManagedObjectID
    ) -> BallotEntity {
        let conversation = entityManager.entityFetcher.existingObject(with: conversation) as? ConversationEntity
        let ballotID = NaClCrypto.shared().randomBytes(Int32(ThreemaProtocol.ballotIDLength)) ?? Data()
        let ballot = entityManager.entityCreator.ballotEntity(id: ballotID)
        ballot.createDate = Date()
        ballot.creatorID = MyIdentityStore.shared().identity
        ballot.title = title
        ballot.type = type.rawValue as NSNumber
        ballot.assessmentType = assessmentType.rawValue as NSNumber
        ballot.displayMode = BallotEntity.BallotDisplayMode.list.rawValue as NSNumber
        ballot.conversation = conversation
        
        choices.enumerated().forEach { [weak self] item in
            let choice = item.element
            let position = item.offset
            let entity = self?.entityManager.entityCreator.ballotChoiceEntity(
                ballotEntity: ballot,
                id: arc4random() as NSNumber
            )
            entity?.name = choice
            entity?.orderPosition = position as NSNumber
        }
        
        return ballot
    }
    
    public func getPollIDs(
        conversation: ConversationEntity? = nil,
        state: BallotEntity.BallotState? = nil
    ) async -> [NSManagedObjectID] {
        await entityManager.entityFetcher.pollIDs(conversation: conversation, state: state)
    }
    
    public func getBallotEntity(for id: NSManagedObjectID) -> BallotEntity? {
        guard let ballotEntity = entityManager.entityFetcher.existingObject(with: id) as? BallotEntity else {
            DDLogError("Could not fetch ballot entity for id: \(id).")
            return nil
        }
        
        return ballotEntity
    }
    
    public func getPoll(for id: NSManagedObjectID) -> Poll? {
        guard let ballotEntity = entityManager.entityFetcher.existingObject(with: id) as? BallotEntity else {
            DDLogError("Could not fetch ballot entity for id: \(id).")
            return nil
        }
        
        let creator: Poll.Creator? =
            if let identity = ballotEntity.creatorID {
                if identity == BusinessInjector.ui.myIdentityStore.identity {
                    .me
                }
                else {
                    entityManager.performAndWait {
                        if let contact = self.entityManager.entityFetcher.contactEntity(for: identity) {
                            .other(displayName: contact.displayName)
                        }
                        else {
                            .other(displayName: identity)
                        }
                    }
                }
            }
            else {
                .other(displayName: #localize("unknown"))
            }
        
        return Poll(for: ballotEntity, creator: creator, identityStore: BusinessInjector.ui.myIdentityStore)
    }
    
    @objc public func choiceResultCount(
        _ ballot: BallotEntity,
        choiceID: NSNumber
    ) -> Int {
        guard let choice = entityManager.entityFetcher.ballotChoiceEntity(for: ballot.id, and: choiceID),
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
        guard let choice = entityManager.entityFetcher.ballotChoiceEntity(for: ballot.id, and: choiceID),
              let result = choice.result else {
            DDLogError("[Ballot] [\(ballot.id.hexString)] Could not fetch choice for ballot.")
            return
        }
        
        for ballotResult in result {
            if !participantIDs.contains(ballotResult.participantID) {
                DDLogWarn(
                    "[Ballot] [\(ballot.id.hexString)] Removed vote (\(ballotResult.participantID) from ballot"
                )
                choice.removeResultForIdentity(ballotResult.participantID)
            }
        }
    }
    
    @objc public func updateBallot(
        _ ballot: BallotEntity,
        choiceID: NSNumber,
        with newValue: NSNumber,
        for contactID: String
    ) {
        guard let choice = entityManager.entityFetcher.ballotChoiceEntity(for: ballot.id, and: choiceID) else {
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
            let newResult = entityManager.entityCreator.ballotResultEntity(
                participantID: contactID,
                ballotChoiceEntity: choice
            )
            newResult.value = newValue
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
        
        let type: SystemMessageEntity.SystemMessageEntityType = updatedVote ? .voteUpdated : .vote
        let sysMsg = entityManager.entityCreator.systemMessageEntity(
            for: type,
            in: conversation
        )
        let date = Date()
        sysMsg.arg = json
        sysMsg.date = date
        sysMsg.remoteSentDate = date
        
        // We intentionally do not save the changes in here. They get saved with the ballot after the last step of
        // decoding.
    }
}
