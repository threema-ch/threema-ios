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
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

@MainActor
final class ListPollViewModel: ObservableObject {
    
    // MARK: - State

    @Published var isLoading = false
    @Published var openPollIDs: [NSManagedObjectID] = []
    @Published var closedPollIDs: [NSManagedObjectID] = []
    @Published var selectedPoll: Poll? = nil
    
    // MARK: - Public properties
    
    let openBallotsTitle = #localize("ballot_open_ballots")
    let closedBallotsTitle = #localize("ballot_closed_ballots")
    let doneTitle = #localize("Done")
    let navigationTitle = #localize("ballots")

    // MARK: - Private properties
    
    private let conversationID: NSManagedObjectID

    private lazy var entityManager = BusinessInjector.ui.entityManager
    private lazy var manager = BallotManager(entityManager: entityManager)
    
    // MARK: - Lifecycle
    
    init(conversationID: NSManagedObjectID) {
        self.conversationID = conversationID
    }
    
    // MARK: - Public functions
    
    func selectPoll(_ poll: Poll) {
        selectedPoll = poll
    }

    func load() async {
        defer {
            isLoading = false
        }
        isLoading = true
        
        guard let conversationEntity = entityManager.entityFetcher
            .existingObject(with: conversationID) as? ConversationEntity else {
            return
        }
        let open = await manager.getPollIDs(conversation: conversationEntity, state: .open)
        let closed = await manager.getPollIDs(conversation: conversationEntity, state: .closed)
       
        withAnimation {
            openPollIDs = open
            closedPollIDs = closed
        }
    }
    
    func load(for id: NSManagedObjectID) -> Poll? {
        manager.getPoll(for: id)
    }
}
