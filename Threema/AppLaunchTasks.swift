//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
import ThreemaFramework

class AppLaunchTasks: NSObject {

    enum LaunchEvent {
        case didFinishLaunching
        case willEnterForeground
    }

    private let backgroundBusinessInjector: BusinessInjectorProtocol
    private static var isRunning = false
    private static let isRunningQueue = DispatchQueue(label: "ch.threema.AppLaunchTasks.isRunningQueue")
    
    // Did the version or build change since the last launch? (This also detects changes between Store, TestFlight and
    // Xcode builds.)
    @objc public static var lastLaunchedVersionChanged: Bool {
        let lastVersion = AppGroup.userDefaults().string(forKey: "LastLaunchedAppVersionAndBuild")
        let currentVersion = ThreemaUtility.appAndBuildVersion
        
        guard let lastVersion else {
            DDLogNotice("Version has changed since last launch of app. Last: nil, current: \(currentVersion)")
            return true
        }
        
        if lastVersion != ThreemaUtility.appAndBuildVersion {
            DDLogNotice(
                "Version has changed since last launch of app. Last: \(lastVersion), current: \(currentVersion)"
            )
            return true
        }
        
        // No change
        return false
    }

    @objc override convenience init() {
        self.init(backgroundBusinessInjector: BusinessInjector(forBackgroundProcess: true))
    }

    required init(backgroundBusinessInjector: BusinessInjectorProtocol) {
        self.backgroundBusinessInjector = backgroundBusinessInjector
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
                backgroundBusinessInjector.entityManager.repairDatabaseIntegrity()
                if AppLaunchTasks.lastLaunchedVersionChanged {
                    Task {
                        do {
                            try await AppUpdateSteps().run()
                            // Only persist last launched version if update steps were successful
                            AppLaunchTasks.updateLastLaunchedVersion()
                        }
                        catch {
                            DDLogWarn("Failed to run application update steps. Try again on next launch. \(error)")
                        }
                    }
                }
            }

            // All other tasks runs in a background thread
            Task {
                await self.checkLastMessageOfAllConversations()
                await backgroundBusinessInjector.messageRetentionManager.deleteOldMessages()
                NotificationManager(businessInjector: backgroundBusinessInjector).updateUnreadMessagesCount()

                // This allows to disable multi-device if MD linking failed with a crash or if all other devices left
                // the MD group
                if launchEvent == .didFinishLaunching {
                    backgroundBusinessInjector.multiDeviceManager.disableMultiDeviceIfNeeded()
                }
                
                AppLaunchTasks.isRunningQueue.async {
                    AppLaunchTasks.isRunning = false
                }
            }
        }
    }
    
    private static func updateLastLaunchedVersion() {
        guard AppLaunchTasks.lastLaunchedVersionChanged else {
            return
        }
        let currentVersion = ThreemaUtility.appAndBuildVersion
        DDLogNotice("Update last launched version to: \(currentVersion)")
        AppGroup.userDefaults().setValue(currentVersion, forKey: "LastLaunchedAppVersionAndBuild")
    }

    /// Checks if the currently assigned last message of given Conversations is actually the correct one and fixes it
    /// if not (and recalculate count of unread messages for this conversation).
    private func checkLastMessageOfAllConversations() async {
        var doUpdateUnreadMessagesCount = false

        await backgroundBusinessInjector.entityManager.performSave {
            guard let conversations = self.backgroundBusinessInjector.entityManager.entityFetcher
                .allConversations() as? [ConversationEntity] else {
                return
            }

            for conversation in conversations {
                guard let effectiveLastMessage = MessageFetcher(
                    for: conversation,
                    with: self.backgroundBusinessInjector.entityManager
                ).lastDisplayMessage() else {
                    conversation.lastMessage = nil
                    continue
                }
                
                if conversation.lastMessage != effectiveLastMessage {
                    DDLogNotice(
                        "Assigned last message \(conversation.lastMessage?.id.hexString ?? "nil") did not equal effective last message \(effectiveLastMessage.id.hexString)"
                    )
                    conversation.lastMessage = effectiveLastMessage

                    self.backgroundBusinessInjector.unreadMessages.count(for: conversation)

                    doUpdateUnreadMessagesCount = true
                }
            }
        }

        if doUpdateUnreadMessagesCount {
            NotificationManager(businessInjector: backgroundBusinessInjector).updateUnreadMessagesCount()
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
