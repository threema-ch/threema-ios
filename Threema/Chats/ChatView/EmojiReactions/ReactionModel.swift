import Combine
import SwiftUI
import ThreemaFramework

final class ReactionModel: ObservableObject {
    // MARK: - Published properties

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
                        userReactionEntries: userReactionEntries,
                        canBeRemoved: info.canBeRemoved
                    ))
                }
                
                return reactionEntries
            }
            .sink(receiveValue: { [weak self] reactionEntries in
                guard let self else {
                    return
                }
                self.reactionEntries = reactionEntries
            })
            .store(in: &subscriptions)
    }
}
