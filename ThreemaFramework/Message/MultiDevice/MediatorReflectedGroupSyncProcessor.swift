//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaEssentials
import ThreemaProtocols

class MediatorReflectedGroupSyncProcessor {
    
    private let frameworkInjector: FrameworkInjectorProtocol

    required init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(groupSync: D2d_GroupSync) -> Promise<Void> {
        Promise { seal in
            Task {
                switch groupSync.action {
                case let .update(groupSyncUpdate):
                    do {
                        try await updateGroupSettings(of: groupSyncUpdate.group)

                        seal.fulfill_()
                    }
                    catch {
                        seal.reject(error)
                    }
                default:
                    seal.fulfill_()
                }
            }
        }
    }

    private func updateGroupSettings(of syncGroup: Sync_Group) async throws {
        let groupIdentity = try GroupIdentity(commonGroupIdentity: syncGroup.groupIdentity)

        guard let group = frameworkInjector.groupManager.getGroup(
            groupIdentity.id,
            creator: groupIdentity.creator.string
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
