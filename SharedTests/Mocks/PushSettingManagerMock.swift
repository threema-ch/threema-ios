import Foundation
import ThreemaEssentials
@testable import ThreemaFramework

final class PushSettingManagerMock: PushSettingManagerProtocol {
    var findForContactCalls = [ThreemaIdentity]()

    func find(forContact identity: ThreemaIdentity) -> PushSetting {
        findForContactCalls.append(identity)
        return PushSetting(identity: identity)
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
