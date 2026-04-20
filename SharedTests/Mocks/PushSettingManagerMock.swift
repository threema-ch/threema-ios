import Foundation
import ThreemaEssentials
@testable import ThreemaFramework

final class PushSettingManagerMock: PushSettingManagerProtocol {
    func find(forContact identity: ThreemaIdentity) -> PushSetting {
        PushSetting(identity: identity)
    }
    
    func find(forGroup groupIdentity: GroupIdentity) -> PushSetting {
        PushSetting(groupIdentity: groupIdentity)
    }
    
    func pushSetting(for pendingUserNotification: PendingUserNotification) -> PushSetting? {
        nil
    }

    func save(pushSetting: PushSetting, sync: Bool) async {
        // no-op
    }

    func delete(forContact identity: ThreemaIdentity) async {
        // no-op
    }

    func canMasterDndSendPush() -> Bool {
        true
    }
    
    func canSendPush(for baseMessage: BaseMessageEntity) -> Bool {
        true
    }
}
