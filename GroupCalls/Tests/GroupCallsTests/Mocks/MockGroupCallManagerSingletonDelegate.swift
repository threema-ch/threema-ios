import Foundation
import ThreemaEssentials
@testable import GroupCalls

final class MockGroupCallManagerSingletonDelegate: GroupCallManagerSingletonDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var incomingCallNotifications = [GroupIdentity]()
    private var bannerButtonUpdates = [GroupCallBannerButtonUpdate]()

    var shownIncomingCallNotifications: [GroupIdentity] {
        lock.withLock { incomingCallNotifications }
    }

    /// All banner and button updates in the order they were received
    var receivedBannerButtonUpdates: [GroupCallBannerButtonUpdate] {
        lock.withLock { bannerButtonUpdates }
    }

    nonisolated func showGroupCallViewController(viewController: GroupCallViewController) {
        // Noop
    }

    nonisolated func updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: GroupCallBannerButtonUpdate) {
        lock.withLock { bannerButtonUpdates.append(groupCallBannerButtonUpdate) }
    }

    func sendStartCallMessage(_ wrappedMessage: WrappedGroupCallStartMessage) async throws {
        // Noop
    }

    nonisolated func showIncomingGroupCallNotification(
        groupModel: GroupCallThreemaGroupModel,
        senderThreemaID: ThreemaIdentity
    ) {
        lock.withLock { incomingCallNotifications.append(groupModel.groupIdentity) }
    }

    nonisolated func showGroupCallFullAlert(maxParticipants: Int?, onOK: @escaping () -> Void) {
        onOK()
    }
    
    func localUserLeftGroupCall(in groupIdentity: ThreemaEssentials.GroupIdentity) {
        // no-op
    }
}
