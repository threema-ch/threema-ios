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

import SwiftUI
import ThreemaMacros

@MainActor
final class VotePollViewModel: ObservableObject {
    
    // MARK: - State

    @Published var poll: Poll?
    @Published var isDeleted = false
    @Published var isVoteEnabled = false
    @Published var showCloseButton = false
    @Published var didChangeSelection = false {
        didSet {
            updateVoteEnabled()
        }
    }

    @Published var selectedChoices: [NSManagedObjectID] = []
    
    // MARK: - Public properties
    
    let pollID: NSManagedObjectID
    
    var pollSectionFooterText: String? {
        guard let poll, !poll.isSummary, poll.isIntermediate || poll.creator == .me else {
            return nil
        }

        return String.localizedStringWithFormat(
            #localize("poll_participants_voted_count"),
            poll.voteCountInfo.countVotes,
            poll.voteCountInfo.countParticipants
        )
    }

    let voteButtonTitle = #localize("ballot_vote")
    let navigationTitle = #localize("ballot")

    let cancelTitle = #localize("cancel")
    let cancelAlertTitle = #localize("voteCancelTitle")
    let cancelAlertMessage = #localize("voteCancelMessage")

    let discardTitle = #localize("discardVoteTitle")

    let closeButtonTitle = #localize("ballot_close")
    let okTitle = #localize("ok")
    
    let closeAlertMessage = #localize("ballot_close_ack")
    
    var pollVoteStateText: String {
        poll?.isMultiSelection == true ? #localize("poll_multi_answer_select") :
            #localize("poll_single_answer_select")
    }
    
    let showVotesButtonTitle = #localize("poll_show_votes")

    // MARK: - Private properties
    
    private var pollObserver: PollObserver?
    private var preSelectedChoices: [NSManagedObjectID] = []
    private var isVoteAllowed = true
    private var didLoad = false
    
    private lazy var entityManager = BusinessInjector.ui.entityManager
    private lazy var manager = BallotManager(entityManager: entityManager)
    private lazy var identityStore = BusinessInjector.ui.myIdentityStore
    private lazy var userSettings = BusinessInjector.ui.userSettings
    private lazy var groupManager = BusinessInjector.ui.groupManager
    private lazy var messageSender = BusinessInjector.ui.messageSender
    
    // MARK: - Lifecycle
    
    init(pollID: NSManagedObjectID) {
        self.pollID = pollID
    }
    
    // MARK: - Public functions
    
    func vote() {
        guard let entity = manager.getBallotEntity(for: pollID),
              let entityChoices = entity.choices else {
            return
        }
        
        let selected = poll?.choices.filter { selectedChoices.contains($0.id) }.map(\.id) ?? []
        for entityChoice in entityChoices {
            let selection = selected.contains(entityChoice.objectID)
            manager.updateOwnChoice(entityChoice, with: NSNumber(booleanLiteral: selection))
        }
        
        entityManager.performAndWaitSave {
            entity.modifyDate = Date()
        }
        messageSender.sendBallotVoteMessage(for: entity)
    }
    
    func close() {
        guard let entity = manager.getBallotEntity(for: pollID) else {
            return
        }
        
        entityManager.performAndWaitSave {
            entity.close()
        }
        messageSender.sendBallotMessage(for: entity)
    }
    
    func select(choice: Poll.Choice) {
        if poll?.isMultiSelection == true {
            var set = Set(selectedChoices)
            set.formSymmetricDifference([choice.id])
            
            selectedChoices = Array(set)
        }
        else {
            selectedChoices = selectedChoices.contains(choice.id) ? [] : [choice.id]
        }
        
        didChangeSelection = Set(preSelectedChoices) != Set(selectedChoices)
    }

    func load() {
        guard !didLoad, let entity = manager.getBallotEntity(for: pollID) else {
            return
        }
        
        updateVoteAllowed(for: entity)
        showCloseButton = entity.canEdit(myIdentity: identityStore.identity)
        
        poll = manager.getPoll(for: pollID)
        poll?.choices.forEach { choice in
            let isChoiceSet = !choice.voters
                .filter { $0.identity == self.identityStore.identity }
                .isEmpty
            
            guard isChoiceSet else {
                return
            }
            
            self.selectedChoices.append(choice.id)
        }
        
        preSelectedChoices = selectedChoices
        didChangeSelection = false
        
        pollObserver = PollObserver(entity: entity)
        bind()
        
        didLoad = true
    }
    
    // MARK: - Private functions
    
    private func bind() {
        pollObserver?.onPollChange = { [weak self] updatedPoll in
            withAnimation {
                self?.poll = updatedPoll
            }
        }

        pollObserver?.onDeleted = { [weak self] in
            self?.isDeleted = true
        }
    }
    
    private func updateVoteEnabled() {
        isVoteEnabled = isVoteAllowed && didChangeSelection
    }
    
    private func updateVoteAllowed(for entity: BallotEntity) {
        let permission = MessagePermission(
            myIdentityStore: identityStore,
            userSettings: userSettings,
            groupManager: groupManager,
            entityManager: entityManager
        )

        guard let conversation = entity.conversation else {
            isVoteAllowed = false
            return
        }

        if let group = groupManager.getGroup(conversation: conversation) {
            isVoteAllowed = permission.canSend(
                groudID: group.groupID,
                groupCreatorIdentity: group.groupCreatorIdentity
            ).isAllowed
        }
        else if let contact = conversation.contact {
            isVoteAllowed = permission.canSend(
                to: contact.identity
            ).isAllowed
        }
        else {
            isVoteAllowed = false
        }
    }
}
