//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

class AppLaunchTasks: NSObject {

    enum LaunchEvent {
        case didFinishLaunching
        case willEnterForeground
    }

    private let businessInjector: BusinessInjectorProtocol
    private static var isRunning = false
    private static let isRunningQueue = DispatchQueue(label: "ch.threema.AppLaunchTasks.isRunningQueue")

    @objc override convenience init() {
        self.init(businessInjector: BusinessInjector())
    }

    required init(businessInjector: BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
    }

    /// Runs some tasks/procedures when the App will be launched or will enter foreground. Especially DB repairing and
    /// checks must be run in the right order. But also other tasks can be started here, with the benefit this tasks
    /// will be run in serial.
    ///
    /// - Parameter launchEvent: App is launching or will enter foreground
    func run(launchEvent: LaunchEvent) {
        AppLaunchTasks.isRunningQueue.sync {
            guard !AppLaunchTasks.isRunning else {
                return
            }
            AppLaunchTasks.isRunning = true

            // Repairs database integrity only on app start and synchronously,
            // must be finished before running other tasks and returning to the caller
            if launchEvent == .didFinishLaunching {
                businessInjector.entityManager.repairDatabaseIntegrity()
            }

            // All other tasks runs in a background thread
            Task {
                await self.checkLastMessageOfAllConversations()

                AppLaunchTasks.isRunningQueue.async {
                    AppLaunchTasks.isRunning = false
                }
            }
        }
    }

    /// Checks if the currently assigned last message of given Conversations is actually the correct one and fixes it
    /// if not (and recalculate count of unread messages for this conversation).
    private func checkLastMessageOfAllConversations() async {
        var doUpdateUnreadMessagesCount = false

        await businessInjector.backgroundEntityManager.performSave {
            guard let conversations = self.businessInjector.backgroundEntityManager.entityFetcher
                .allConversations() as? [Conversation] else {
                return
            }

            for conversation in conversations {
                guard let effectiveLastMessage = MessageFetcher(
                    for: conversation,
                    with: self.businessInjector.backgroundEntityManager
                ).lastMessage() else {
                    conversation.lastMessage = nil
                    continue
                }

                if conversation.lastMessage != effectiveLastMessage {
                    DDLogWarn(
                        "Assigned last message \(conversation.lastMessage?.id.hexString ?? "nil") did not equal effective last message \(effectiveLastMessage.id.hexString)"
                    )
                    conversation.lastMessage = effectiveLastMessage

                    self.businessInjector.backgroundUnreadMessages.count(for: conversation)

                    doUpdateUnreadMessagesCount = true
                }
            }
        }

        if doUpdateUnreadMessagesCount {
            NotificationManager(businessInjector: businessInjector).updateUnreadMessagesCount()
        }
    }
}

extension AppLaunchTasks {
    @objc func runLaunchEventDidFinishLaunching() {
        run(launchEvent: .didFinishLaunching)
    }

    @objc func runLaunchEventWillEnterForeground() {
        run(launchEvent: .willEnterForeground)
    }
}
