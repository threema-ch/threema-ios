import Foundation

final class PollObserver {
    
    // MARK: - Public properties
    
    var onPollChange: ((Poll) -> Void)?
    var onDeleted: (() -> Void)?

    // MARK: - Private properties
    
    private let entity: BallotEntity
    private let sortOrder: Poll.ChoiceSortOrder
    private var notificationObserver: NSObjectProtocol?
    
    // MARK: - Lifecycle

    init(entity: BallotEntity, sortOrder: Poll.ChoiceSortOrder = .order) {
        self.sortOrder = sortOrder
        self.entity = entity
        
        observeContext()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Private observers

    private func observeContext() {
        guard let context = entity.managedObjectContext else {
            return
        }

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] notification in
            self?.handleContextChange(notification)
        }
    }

    private func handleContextChange(_ notification: Notification) {
        if entity.isDeleted || entity.willBeDeleted {
            onDeleted?()
            return
        }

        let relevantTypes: [NSManagedObject.Type] = [
            BallotEntity.self,
            BallotChoiceEntity.self,
            BallotResultEntity.self,
        ]
        let changed = (notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? [])
            .union(notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? [])
            .union(notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? [])

        let affectsThisPoll = changed
            .contains { object in relevantTypes.contains { type(of: object) == $0 } && isRelatedToCurrentPoll(object) }

        if affectsThisPoll {
            handlePollChange()
        }
    }

    private func isRelatedToCurrentPoll(_ object: NSManagedObject) -> Bool {
        if object == entity {
            return true
        }
        if let choice = object as? BallotChoiceEntity, choice.ballot == entity {
            return true
        }
        if let result = object as? BallotResultEntity, result.ballotChoice.ballot == entity {
            return true
        }
        return false
    }
    
    private func handlePollChange() {
        Task { @MainActor in
            onPollChange?(Poll(for: entity, sortOrder: sortOrder, identityStore: BusinessInjector.ui.myIdentityStore))
        }
    }
}
