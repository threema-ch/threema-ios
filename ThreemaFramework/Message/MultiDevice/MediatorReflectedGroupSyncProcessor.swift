import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaEssentials
import ThreemaProtocols

final class MediatorReflectedGroupSyncProcessor {
    
    private let frameworkInjector: FrameworkInjectorProtocol

    required init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(groupSync: D2d_GroupSync) -> Promise<Void> {
        Promise { seal in
            Task {
                do {
                    switch groupSync.action {
                    case .create:
                        DDLogWarn("D2D group sync create not implemented yet")
                    case let .delete(sync):
                        try await delete(groupIdentity: sync.groupIdentity)
                    case let .update(groupSyncUpdate):
                        try await updateGroupSettings(of: groupSyncUpdate.group)
                    case .none:
                        DDLogWarn("D2D group sync is none")
                    }

                    seal.fulfill_()
                }
                catch {
                    seal.reject(error)
                }
            }
        }
    }

    private func delete(groupIdentity commonGroupIdentity: Common_GroupIdentity) async throws {
        let groupIdentity = try GroupIdentity(commonGroupIdentity: commonGroupIdentity)

        guard let group = frameworkInjector.groupManager.getGroup(
            groupIdentity.id,
            creator: groupIdentity.creator.rawValue
        )
        else {
            throw MediatorReflectedProcessorError.groupToDeleteNotExists(groupIdentity: groupIdentity)
        }

        guard group.state != .active else {
            throw MediatorReflectedProcessorError.groupToDeleteIsActive(groupIdentity: groupIdentity)
        }

        await frameworkInjector.entityManager.performSave {
            if let conversationEntity = self.frameworkInjector.entityManager.entityFetcher
                .conversationEntity(with: group.conversationObjectID) {
                self.frameworkInjector.entityManager.entityDestroyer.delete(conversation: conversationEntity)
            }
        }
    }

    private func updateGroupSettings(of syncGroup: Sync_Group) async throws {
        let groupIdentity = try GroupIdentity(commonGroupIdentity: syncGroup.groupIdentity)

        guard let group = frameworkInjector.groupManager.getGroup(
            groupIdentity.id,
            creator: groupIdentity.creator.rawValue
        )
        else {
            throw MediatorReflectedProcessorError.groupToUpdateNotExists(groupIdentity: groupIdentity)
        }

        // Save on main thread (main DB context), otherwise observer of `Conversation` will not be
        // called
        frameworkInjector.conversationStoreInternal.updateConversation(withGroup: syncGroup)

        var pushSetting = frameworkInjector.pushSettingManager
            .find(forGroup: group.groupIdentity)
        pushSetting.update(syncGroup: syncGroup)
        await frameworkInjector.pushSettingManager.save(
            pushSetting: pushSetting,
            sync: false
        )
    }
}
