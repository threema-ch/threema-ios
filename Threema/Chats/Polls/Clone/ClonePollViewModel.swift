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

import ThreemaFramework
import ThreemaMacros

@MainActor
final class ClonePollViewModel: ObservableObject {
    
    // MARK: - State

    @Published var isLoading = false
    @Published var pollIDs: [NSManagedObjectID] = []
    
    // MARK: - Private properties
    
    private lazy var entityManager = BusinessInjector.ui.entityManager
    private lazy var manager = BallotManager(entityManager: entityManager)
    
    // MARK: - Public functions

    func load() async {
        defer {
            isLoading = false
        }
        
        isLoading = true
        pollIDs = await manager.getPollIDs()
    }
    
    func load(for id: NSManagedObjectID) -> Poll? {
        manager.getPoll(for: id)
    }
}
