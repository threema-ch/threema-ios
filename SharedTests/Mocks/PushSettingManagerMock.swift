import Foundation
import ThreemaEssentials
@testable import ThreemaFramework

final class PushSettingManagerMock: PushSettingManagerProtocol {
    var findForContactCalls = [ThreemaIdentity]()

    /// Push settings `find(forGroup:)` returns for their group instead of the default
    var groupPushSettings = [PushSetting]()

    /// Push settings passed to `save(pushSetting:sync:)`, in order
    private(set) var savedPushSettings = [PushSetting]()

    func find(forContact identity: ThreemaIdentity) -> PushSetting {
        findForContactCalls.append(identity)
        return PushSetting(identity: identity)
    }

    func find(forGroup groupIdentity: GroupIdentity) -> PushSetting {
        groupPushSettings.first { $0.groupIdentity == groupIdentity } ?? PushSetting(groupIdentity: groupIdentity)
    }

    func pushSetting(for pendingUserNotification: PendingUserNotification) -> PushSetting? {
        nil
    }

    func save(pushSetting: PushSetting, sync: Bool) async {
        savedPushSettings.append(pushSetting)
    }

    func delete(forContact identity: ThreemaIdentity) async {
        // no-op
    }

    func canMasterDndSendPush() -> Bool {
        true
    }
    
    func canSendPush(for baseMessage: BaseMessageEntity, isReaction: Bool) -> Bool {
        true
    }
}
