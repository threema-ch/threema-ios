import SwiftUI
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

@MainActor
final class ListPollViewModel: ObservableObject {
    
    // MARK: - State

    @Published var isLoading = false
    @Published var showDeleteAlert = false
    @Published var openPollIDs: [NSManagedObjectID] = []
    @Published var closedPollIDs: [NSManagedObjectID] = []
    @Published var selectedPoll: Poll? = nil
    
    // MARK: - Public properties
    
    let openBallotsTitle = #localize("ballot_open_ballots")
    let closedBallotsTitle = #localize("ballot_closed_ballots")
    let doneTitle = #localize("Done")
    let navigationTitle = #localize("ballots")
    let deleteAlertTitle = #localize("ballot_alert_delete_own_open_poll_title")
    let deleteAlertOkButtonTitle = #localize("ok")

    // MARK: - Private properties
    
    private let conversationID: NSManagedObjectID
    private let entityManager: EntityManager
    private let onDelete: (([NSManagedObjectID]) -> Void)?

    private lazy var manager = BallotManager(entityManager: entityManager)
    
    // MARK: - Lifecycle
    
    init(
        conversationID: NSManagedObjectID,
        entityManager: EntityManager,
        onDelete: (([NSManagedObjectID]) -> Void)? = nil
    ) {
        self.conversationID = conversationID
        self.entityManager = entityManager
        self.onDelete = onDelete
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
    
    func deletePoll(at index: Int, closedPoll: Bool) {
        let managedObjectID = closedPoll ? closedPollIDs.remove(at: index) : openPollIDs.remove(at: index)
        guard let ballotEntity = entityManager.entityFetcher.managedObject(with: managedObjectID) as? BallotEntity
        else {
            Task {
                await load()
            }
            return
        }
        
        guard closedPoll ||
            !closedPoll && ballotEntity.creatorID != BusinessInjector().myIdentityStore.identity else {
            Task {
                await load()
            }
            showDeleteAlert = true
            return
        }
        
        if let ballotMessagesManagedObjectIDs = ballotEntity.message?.compactMap({ ballotMessageEntity in
            ballotMessageEntity.objectID
        }) as? [NSManagedObjectID] {
            onDelete?(ballotMessagesManagedObjectIDs)
        }
                
        entityManager.performAndWaitSave {
            
            ballotEntity.message?.forEach { baseMessageEntity in
                self.entityManager.entityDestroyer.delete(baseMessage: baseMessageEntity)
            }
            self.entityManager.entityDestroyer.delete(ballot: ballotEntity)
        }
        
        guard let conversationEntity = entityManager.entityFetcher
            .existingObject(with: conversationID) as? ConversationEntity else {
            return
        }
        conversationEntity.updateLastDisplayMessage(with: entityManager)
    }
}
