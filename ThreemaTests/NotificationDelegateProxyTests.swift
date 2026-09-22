import Foundation
import PushKit
import Testing
import UserNotifications
@testable import Threema

@MainActor
struct NotificationDelegateProxyTests {

    @Test
    func queuesCallbacksUntilAttachThenReplaysInOrder() async {
        let proxy = NotificationDelegateProxy(pushRegistry: PKPushRegistry(queue: .main))
        let target = NotificationDelegateSpy()
        let center = UNUserNotificationCenter.current()

        proxy.userNotificationCenter(center, openSettingsFor: nil)
        proxy.userNotificationCenter(center, openSettingsFor: nil)
        proxy.userNotificationCenter(center, openSettingsFor: nil)

        await drainDispatchTasks()

        #expect(await target.openSettingsCount == 0)

        proxy.attach(target)
        await drainDispatchTasks()

        #expect(await target.openSettingsCount == 3)
    }

    @Test
    func forwardsSynchronouslyAfterAttach() async {
        let proxy = NotificationDelegateProxy(pushRegistry: PKPushRegistry(queue: .main))
        let target = NotificationDelegateSpy()
        proxy.attach(target)

        proxy.userNotificationCenter(UNUserNotificationCenter.current(), openSettingsFor: nil)

        await drainDispatchTasks()

        #expect(await target.openSettingsCount == 1)
    }

    @Test
    func reattachAfterDetachDoesNotReplayDrainedItems() async {
        let proxy = NotificationDelegateProxy(pushRegistry: PKPushRegistry(queue: .main))
        let center = UNUserNotificationCenter.current()

        // Queue 3 items, attach first target, drain.
        proxy.userNotificationCenter(center, openSettingsFor: nil)
        proxy.userNotificationCenter(center, openSettingsFor: nil)
        proxy.userNotificationCenter(center, openSettingsFor: nil)
        await drainDispatchTasks()

        let first = NotificationDelegateSpy()
        proxy.attach(first)
        await drainDispatchTasks()
        #expect(await first.openSettingsCount == 3)

        // Detach, queue one more, attach a second target. The second target must see only the new
        // item — not the three already delivered to `first`.
        proxy.detach()
        proxy.userNotificationCenter(center, openSettingsFor: nil)
        await drainDispatchTasks()

        let second = NotificationDelegateSpy()
        proxy.attach(second)
        await drainDispatchTasks()

        #expect(await second.openSettingsCount == 1)
        #expect(await first.openSettingsCount == 3)
    }

    @Test
    func detachStopsForwarding() async {
        let proxy = NotificationDelegateProxy(pushRegistry: PKPushRegistry(queue: .main))
        let target = NotificationDelegateSpy()
        proxy.attach(target)
        proxy.detach()

        proxy.userNotificationCenter(UNUserNotificationCenter.current(), openSettingsFor: nil)

        await drainDispatchTasks()

        #expect(await target.openSettingsCount == 0)
    }

    /// Yields enough times for any `Task { @MainActor in … }` enqueued by the proxy plus the
    /// follow-up `Task { await recorder … }` enqueued by the spy to complete before assertions
    /// run.
    private func drainDispatchTasks() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }
}

// MARK: - Helpers

// MARK: NotificationDelegateSpy

private final class NotificationDelegateSpy: NSObject, NotificationDelegating, @unchecked Sendable {

    private actor Recorder {
        var openSettingsCount = 0
        
        func recordOpenSettings() {
            openSettingsCount += 1
        }
    }

    private let recorder = Recorder()

    var openSettingsCount: Int {
        get async {
            await recorder.openSettingsCount
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        Task {
            await recorder.recordOpenSettings()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate credentials: PKPushCredentials,
        for type: PKPushType
    ) { }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        completion()
    }
}
