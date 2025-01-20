//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import Combine
import SwiftUI
import ThreemaFramework

class ReactionModel: ObservableObject {
    // MARK: - Published properties

    @Published var showInfoBox = false
    @Published var prevCountPerReaction: [String: Int] = [:]
    @Published var countPerReaction: [String: Int] = [:]
    @Published var reactionEntries: [ReactionEntry] = [] {
        // This is used to give SwiftUI a diff that it can use to animate the number changes.
        willSet {
            prevCountPerReaction = reactionEntries.reduce(into: [:]) {
                $0[$1.reaction] = $1.userReactionEntries.count
            }
        }
        didSet {
            countPerReaction = reactionEntries.reduce(into: [:]) {
                $0[$1.reaction] = $1.userReactionEntries.count
            }
        }
    }
    
    // MARK: - Private properties

    private var subscriptions: Set<AnyCancellable> = .init()
    private var reactionManager: any ReactionsModalDelegate
    
    // MARK: - Lifecycle

    init(_ reactionManager: any ReactionsModalDelegate) {
        self.reactionManager = reactionManager
        observeChanges()
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    // MARK: - Functions
    
    func removeOwnReaction(_ reaction: EmojiVariant) {
        reactionManager.send(reaction)
    }
    
    private func observeChanges() {
        reactionManager.currentReactionsByCreatorPublisher
            .map { reactionInfo in
                var reactionEntries: [ReactionEntry] = []
                
                for info in reactionInfo {
                    var userReactionEntries: [UserReactionEntry] = []
                    
                    for contact in info.contacts {
                        userReactionEntries.append(UserReactionEntry(user: contact, sortDate: info.sortDate))
                    }
                    
                    reactionEntries.append(ReactionEntry(
                        reaction: info.reactionString,
                        userReactionEntries: userReactionEntries
                    ))
                }
                
                return reactionEntries
            }
            .sink(receiveValue: { [weak self] reactionEntries in
                guard let self else {
                    return
                }
                self.reactionEntries = reactionEntries
                checkInfoBox()
            })
            .store(in: &subscriptions)
    }
    
    private func checkInfoBox() {
        guard !UserSettings.shared().sendEmojiReactions else {
            return
        }
        
        for reactionEntry in reactionEntries {
            // If we cannot map the reaction, we assume it is not ack/deck mappable anyway
            guard let emoji = Emoji(rawValue: reactionEntry.reaction) else {
                showInfoBox = true
                return
            }
            
            if emoji.applyLegacyMapping() == nil {
                showInfoBox = true
                break
            }
        }
    }
}
