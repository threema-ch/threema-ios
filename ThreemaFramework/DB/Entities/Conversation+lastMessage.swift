//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

public extension Conversation {
    
    func updateLastMessage(with entityManager: EntityManager) {
        entityManager.performSyncBlockAndSafe {

            let fetcher = MessageFetcher(for: self, with: entityManager)
            guard let message = fetcher.lastMessage() else {
                self.lastMessage = nil
                return
            }
            
            guard self.lastMessage != message else {
                return
            }
            
            self.lastMessage = message
        }
    }
}