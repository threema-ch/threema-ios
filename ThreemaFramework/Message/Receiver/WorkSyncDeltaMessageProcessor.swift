import CocoaLumberjackSwift
import Foundation
import ThreemaProtocols

final class WorkSyncDeltaMessageProcessor: NSObject {

    private let appGroupType: AppGroupType
    private let entityManager: EntityManager
    private let messageProcessorDelegate: MessageProcessorDelegate
    private let userSettings: any UserSettingsProtocol
    private let taskManager: any TaskManagerProtocol
    private let workDataFetcher: any WorkDataFetcherProtocol

    required init(
        appGroupType: AppGroupType,
        entityManager: EntityManager,
        messageProcessorDelegate: MessageProcessorDelegate,
        userSettings: any UserSettingsProtocol,
        taskManager: any TaskManagerProtocol,
        workDataFetcher: any WorkDataFetcherProtocol
    ) {
        self.appGroupType = appGroupType
        self.entityManager = entityManager
        self.messageProcessorDelegate = messageProcessorDelegate
        self.userSettings = userSettings
        self.taskManager = taskManager
        self.workDataFetcher = workDataFetcher
        super.init()
    }

    @objc convenience init(
        appGroupType: AppGroupType,
        entityManager: EntityManager,
        messageProcessorDelegate: MessageProcessorDelegate
    ) {
        let apiCaller = WorkDataAPICaller(licenseStore: LicenseStore.shared())
        let mdmSetup = MDMSetup()!
        let appFlavorService = AppFlavorService()

        let workDataThreemaMDMFetcher = WorkDataThreemaMDMFetcher(
            mdmSetup: mdmSetup,
            licenseStore: LicenseStore.shared(),
            appFlavorService: appFlavorService,
            workDataAPICaller: apiCaller
        )

        self.init(
            appGroupType: appGroupType,
            entityManager: entityManager,
            messageProcessorDelegate: messageProcessorDelegate,
            userSettings: UserSettings.shared(),
            taskManager: TaskManager(
                backgroundEntityManager: entityManager,
                serverConnector: ServerConnector.shared()
            ),
            workDataFetcher: WorkDataFetcher(
                contactStore: ContactStore.shared(),
                licenseStore: LicenseStore.shared(),
                identityStore: MyIdentityStore.shared(),
                userSettings: UserSettings.shared(),
                userDefaults: AppGroup.userDefaults(),
                serverInfoProvider: ServerInfoProviderFactory.makeServerInfoProvider(),
                appFlavorService: AppFlavorService(),
                entityManager: entityManager,
                mdmSetup: mdmSetup,
                workDataAPICaller: apiCaller,
                workDataThreemaMDMFetcher: workDataThreemaMDMFetcher
            )
        )
    }

    @objc func handle(message abstractMessage: WorkSyncDeltaMessage) async throws {
        // 5. If `action` is an unknown variant, log a warning that an unknown Work Sync variant has been encountered.
        guard let action = abstractMessage.decoded?.action else {
            DDLogError("Decoded message has no action.")
            return
        }

        switch action {

        case .requireWorkSync:
            // 3. If `action` is of variant `require_work_sync`, schedule a persistent task to make a full Work Sync.
            try await triggerFullWorkSync()

        case let .apply(apply):
            // 4. If `action` is of variant `apply`:

            // 1. Run the _Work Sync Delta Change Determination Steps_ with `apply.deltas` and let `changes` be the
            // result
            let changes = try await determineChanges(from: apply.deltas)

            // 3. If `changes` is empty, discard the message and abort these steps.
            guard !changes.isEmpty else {
                DDLogInfo("No work sync changes to sync.")
                return
            }

            // 4. (MD) Run the following sub-steps:
            if !userSettings.enableMultiDevice {
                DDLogInfo("MD disabled, not reflecting work sync changes.")
                entityManager.updateWorkAvailabilityStatus(changes: changes) { objectID in
                    self.messageProcessorDelegate.changedManagedObjectID(objectID)
                }
            }
            else {
                // Execute sub task to reflect changes
                try await taskManager.executeSubTask(
                    taskDefinition: TaskDefinitionReflectWorkSyncDelta(
                        deltas: apply.deltas,
                        determineChanges: { changes in
                            try await self.determineChanges(from: changes)
                        },
                        changedManagedObjectID: { objectID in
                            self.messageProcessorDelegate.changedManagedObjectID(objectID)
                        }
                    )
                )
            }
        }
    }

    private func determineChanges(from deltas: [CspE2e_WorkSyncDelta.Delta]) async throws -> [D2dSync_Contact] {
        // 1. Let `deltas` be a list of `WorkSyncDelta.Delta`.
        // 2. Let `changes` be an empty list of _change instructions_ that would be
        var changes = [D2dSync_Contact]()

        // 3. For each `delta` of `deltas`:
        for delta in deltas {

            guard let action = delta.action else {
                DDLogError("Received unknown Work Sync Delta action. Skipping.")
                continue
            }

            switch action {
            // 1. If `delta.action` is of variant `contact_sync`:
            case let .contactSync(contactSync):

                guard let contactSyncAction = contactSync.action else {
                    // 2. If `contact_sync.action` is an unknown variant, log a warning that an unknown Work Sync Delta
                    // contact action has been encountered.
                    DDLogError("Received unknown Work Sync Delta action. Skipping.")
                    continue
                }

                switch contactSyncAction {
                // 1. If `contact_sync.action` is of variant `update`:
                case let .update(update):
                    // 1. Lookup the contact associated to `update.identity` and let `contact` be the result.
                    let (contactEntity, isWorkContact, workLastFullSyncAt) = entityManager.performAndWait {
                        let contact = self.entityManager.entityFetcher.contactEntity(for: update.identity)
                        return (contact, contact?.isWorkContact, contact?.workLastFullSyncAt)
                    }

                    // 2. If `contact` is not defined, discard `update` and continue with the next delta.
                    guard let contactEntity else {
                        continue
                    }

                    // 3. If `contact` is not currently considered a work contact, return that a _full Work Sync is
                    // required_.
                    guard let isWorkContact, isWorkContact else {
                        try await triggerFullWorkSync()
                        return []
                    }

                    //  4. If `contact`'s last full Work Sync timestamp is defined and ≥ `delta.applied_at`, discard
                    //  `update` and continue with the next delta.
                    if let workLastFullSyncAt, workLastFullSyncAt.millisecondsSince1970 >= delta.appliedAt {
                        continue
                    }

                    // 5. If `update` does not diverge from the properties of `contact`, discard `update` and
                    // continue with the next delta.²
                    // Note: We only check for status at the moment, when other properties are added, this needs some
                    // rework.

                    if let change = checkDiverges(update: update, for: contactEntity) {
                        changes.append(change)
                    }
                }
            }
        }

        // 4. Return `changes`.
        return changes
    }

    private func checkDiverges(
        update: CspE2e_WorkSyncDelta.ContactSync.Update,
        for contactEntity: ContactEntity
    ) -> D2dSync_Contact? {
        // WorkAvailabilityState
        let newState = WorkAvailabilityStatus(d2dStatus: update.availabilityStatus)
        let (value, text, identity) = entityManager.performAndWait {
            (
                contactEntity.workAvailabilityStatus?.value,
                contactEntity.workAvailabilityStatus?.text,
                contactEntity.identity
            )
        }

        // 5. If `update` does not diverge from the properties of `contact`, discard `update` and continue with the next
        // delta.²
        guard newState.category.rawValue != value?.intValue || newState.description != text else {
            return nil
        }

        // 6. Add a change to `changes` for the necessary changes defined by `update` to update the `contact` in form of
        // a `d2d_sync.Contact`.
        var contact = D2dSync_Contact()
        contact.identity = identity
        contact.update(workAvailabilityStatus: newState)

        return contact
    }

    private func triggerFullWorkSync() async throws {
        if appGroupType == AppGroupTypeApp {
            DDLogInfo("Run full Work Sync")
            try await workDataFetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        }
        else {
            DDLogInfo("Reset last Work Sync")
            workDataFetcher.resetLastSync()
        }
    }
}
