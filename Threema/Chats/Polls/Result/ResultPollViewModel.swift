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
final class ResultPollViewModel: ObservableObject {
    
    // MARK: - State

    @Published var poll: Poll?
    @Published var isDeleted = false
    @Published var expandedStates: [NSManagedObjectID: Bool] = [:]
    
    // MARK: - Public properties
    
    let doneTitle = #localize("Done")

    var navigationTitle: String {
        poll?.isClosed ?? false ? #localize("ballot_results") : #localize("ballot_intermediate_results")
    }
    
    var headerTitle: String {
        poll?.title ?? #localize("unknown")
    }
    
    var headerText: String? {
        guard let poll, !poll.isSummary else {
            return nil
        }
        
        return String(
            format: #localize("poll_participants_voted_count"),
            poll.voteCountInfo.countVotes,
            poll.voteCountInfo.countParticipants
        )
    }
    
    let choicesTitle = #localize("ballot_options")
    let noVotesTitle = #localize("poll_no_response")
    var pollVotesCount = #localize("poll_votes_count")
    
    // MARK: - Private properties
    
    private let pollID: NSManagedObjectID
    private var pollObserver: PollObserver?
    
    private lazy var entityManager = BusinessInjector.ui.entityManager
    private lazy var manager = BallotManager(entityManager: entityManager)
    
    // MARK: - Lifecycle
    
    init(pollID: NSManagedObjectID) {
        self.pollID = pollID
    }
    
    // MARK: - Public functions

    func load() {
        guard let entity = manager.getBallotEntity(for: pollID) else {
            return
        }
        
        poll = manager.getPoll(for: pollID)
        pollObserver = PollObserver(entity: entity, sortOrder: .votes)
        bind()
        
        if let choices = poll?.choices {
            let maxVotes = choices.map(\.votes).max() ?? 0
            for choice in choices where choice.votes == maxVotes && maxVotes > 0 {
                expandedStates[choice.id] = true
            }
        }
    }
    
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
}
