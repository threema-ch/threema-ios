import Combine
import CoreData
import Foundation
import os
import Testing
@testable import Threema
@testable import ThreemaFramework

@Suite("CoreDataContactListProvider", .serialized)
@MainActor
final class CoreDataContactListProviderTests {

    // MARK: - Nested types

    /// Records the threads snapshots are delivered on, from any thread
    private final class DeliveryRecorder: Sendable {
        private let deliveredOnMainThread = OSAllocatedUnfairLock(initialState: [Bool]())

        var deliveries: [Bool] {
            deliveredOnMainThread.withLock { $0 }
        }

        func record() {
            let isMainThread = Thread.isMainThread
            deliveredOnMainThread.withLock { $0.append(isMainThread) }
        }

        func reset() {
            deliveredOnMainThread.withLock { $0.removeAll() }
        }
    }

    /// Counts `performFetch()` calls across all controllers sharing it
    private final class FetchCounter: Sendable {
        private let lockedCount = OSAllocatedUnfairLock(initialState: 0)

        var count: Int {
            lockedCount.withLock { $0 }
        }

        func increment() {
            lockedCount.withLock { $0 += 1 }
        }
    }

    private final class CountingFetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> {
        var fetchCounter: FetchCounter?

        override func performFetch() throws {
            fetchCounter?.increment()
            try super.performFetch()
        }
    }

    // MARK: - Private properties

    private let testDatabase: TestDatabase
    private let userSettings: UserSettings

    // MARK: - Lifecycle

    init() {
        AppGroup.setGroupID("group.ch.threema")
        testDatabase = TestDatabase()
        userSettings = UserSettings.shared()
    }

    // MARK: - Tests

    @Test("A setting written on a background thread does not wait for the main thread")
    func backgroundSettingChangeDoesNotWaitForMainThread() async throws {
        let initialHideStaleContacts = userSettings.hideStaleContacts
        defer {
            userSettings.hideStaleContacts = initialHideStaleContacts
        }

        let provider = makeProvider()
        await drainMainQueue()

        let recorder = DeliveryRecorder()
        let subscription = provider.currentSnapshot
            .dropFirst()
            .sink { _ in
                recorder.record()
                // Stand-in for `UITableViewDiffableDataSource.apply(_:)`, which waits for main when called off main
                if !Thread.isMainThread {
                    DispatchQueue.main.sync { }
                }
            }
        defer {
            subscription.cancel()
        }

        let setterReturned = DispatchSemaphore(value: 0)
        let userSettings = userSettings
        let newValue = !initialHideStaleContacts
        DispatchQueue.global(qos: .userInitiated).async {
            userSettings.hideStaleContacts = newValue
            setterReturned.signal()
        }

        // Keep main busy, as in the crash where main was writing the same setting. A setter that waits for main
        // times out here instead of deadlocking the test.
        #expect(
            setterReturned.wait(timeout: .now() + 2) == .success,
            "The setter on the background thread waited for the main thread"
        )

        try await waitForDelivery(of: recorder)
        // swiftformat:disable:next preferKeyPath
        #expect(recorder.deliveries.allSatisfy { $0 }, "Snapshots must only be delivered on the main thread")
    }

    @Test("Each observed setting publishes a new snapshot on the main thread")
    func observedSettingsPublishOnMainThread() async throws {
        let initialHideStaleContacts = userSettings.hideStaleContacts
        let initialSortOrderFirstName = userSettings.sortOrderFirstName
        defer {
            userSettings.hideStaleContacts = initialHideStaleContacts
            userSettings.sortOrderFirstName = initialSortOrderFirstName
        }

        let provider = makeProvider()
        await drainMainQueue()

        let recorder = DeliveryRecorder()
        let subscription = provider.currentSnapshot
            .dropFirst()
            .sink { _ in
                recorder.record()
            }
        defer {
            subscription.cancel()
        }

        let userSettings = userSettings

        await runOnBackgroundThread {
            userSettings.hideStaleContacts = !initialHideStaleContacts
        }
        try await waitForDelivery(of: recorder, "hideStaleContacts")
        // swiftformat:disable:next preferKeyPath
        #expect(recorder.deliveries.allSatisfy { $0 }, "hideStaleContacts: delivered off the main thread")

        recorder.reset()

        await runOnBackgroundThread {
            userSettings.sortOrderFirstName = !initialSortOrderFirstName
        }
        try await waitForDelivery(of: recorder, "sortOrderFirstName")
        // swiftformat:disable:next preferKeyPath
        #expect(recorder.deliveries.allSatisfy { $0 }, "sortOrderFirstName: delivered off the main thread")
    }

    @Test(
        "The block list subscription fetches once per blocked identity at init, then never again",
        arguments: [[String](), ["ECHOECHO"], ["ECHOECHO", "AAAAAAAA", "BBBBBBBB"]]
    )
    func blockListSubscriptionOnlyRunsDuringInit(blockedIdentities: [String]) async throws {
        let settingsStore = SettingsStoreMock()
        settingsStore.blacklist = Set(blockedIdentities)

        let fetchCounter = FetchCounter()
        let provider = makeProvider(settingsStore: settingsStore, fetchCounter: fetchCounter)
        await drainMainQueue()

        // One fetch from `init` itself, plus one per element emitted by `Set.publisher` while subscribing
        #expect(fetchCounter.count == 1 + blockedIdentities.count)

        // The store does publish block list changes...
        var storeEmissions = 0
        let storeSubscription = settingsStore.$blacklist
            .dropFirst()
            .sink { _ in
                storeEmissions += 1
            }
        defer {
            storeSubscription.cancel()
        }

        settingsStore.blacklist.insert("CCCCCCCC")
        settingsStore.blacklist = ["DDDDDDDD"]
        nonisolated(unsafe) let backgroundSettingsStore = settingsStore
        await runOnBackgroundThread {
            backgroundSettingsStore.blacklist = []
        }
        await drainMainQueue()
        try await Task.sleep(for: .milliseconds(200))
        await drainMainQueue()

        #expect(storeEmissions == 3, "The store did not publish the block list changes")

        // ...but the provider never fetches again
        #expect(
            fetchCounter.count == 1 + blockedIdentities.count,
            "The provider reacted to a block list change"
        )

        withExtendedLifetime(provider) { }
    }

    // MARK: - Private helpers

    private func makeProvider(
        settingsStore: SettingsStoreMock,
        fetchCounter: FetchCounter
    ) -> CoreDataContactListProvider<ContactEntity, Contact> {
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let userSettings = userSettings

        return CoreDataContactListProvider(
            entityFetcher: entityFetcher,
            userSettings: userSettings,
            settingsStore: settingsStore,
            fetchedResultsController: {
                let template = entityFetcher.contactsResultController(
                    sortOrderFirstName: userSettings.sortOrderFirstName,
                    hideStaleContacts: userSettings.hideStaleContacts
                )
                let controller = CountingFetchedResultsController(
                    fetchRequest: template.fetchRequest,
                    managedObjectContext: template.managedObjectContext,
                    sectionNameKeyPath: template.sectionNameKeyPath,
                    cacheName: nil
                )
                controller.fetchCounter = fetchCounter
                return controller
            },
            entityResolver: { Contact(contactEntity: $0) }
        )
    }

    private func makeProvider() -> CoreDataContactListProvider<ContactEntity, Contact> {
        let entityFetcher = testDatabase.entityManager.entityFetcher
        let userSettings = userSettings

        return CoreDataContactListProvider(
            entityFetcher: entityFetcher,
            userSettings: userSettings,
            settingsStore: SettingsStoreMock(),
            fetchedResultsController: {
                entityFetcher.contactsResultController(
                    sortOrderFirstName: userSettings.sortOrderFirstName,
                    hideStaleContacts: userSettings.hideStaleContacts
                )
            },
            entityResolver: { Contact(contactEntity: $0) }
        )
    }

    private func runOnBackgroundThread(_ work: @escaping @Sendable () -> Void) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                work()
                continuation.resume()
            }
        }
    }

    /// Returns after everything enqueued on the main queue so far ran
    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    /// Suspends (letting the main queue run) until a delivery was recorded or the timeout elapsed, then collects
    /// the deliveries still enqueued on the main queue
    private func waitForDelivery(
        of recorder: DeliveryRecorder,
        _ comment: Comment? = nil,
        timeout: Duration = .seconds(5)
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while recorder.deliveries.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        await drainMainQueue()
        try #require(!recorder.deliveries.isEmpty, comment ?? "Expected a snapshot delivery")
    }
}
