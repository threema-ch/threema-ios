//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import BackgroundTasks
import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

/// Manages everything related to BGTasks. Always use the shared instance.
///
/// New task need to adapt `ThreemaBackgroundTask` and be added to the `tasks` array below.
class ThreemaBGTaskManager: NSObject {
    
    /// This will call `registerTasks()` below and register all tasks during initialization.
    /// This **MUST** be called in `didFinishLaunchingWithOptions` otherwise the app will crash during scheduling of
    /// the tasks. This is why we initialize the shared instance there and `init` is private.
    @objc public static let shared = ThreemaBGTaskManager()
    
    // MARK: - Tasks

    // Add new tasks here
    private let tasks: [ThreemaBackgroundTask] = [
        MessagesRetentionBackgroundTask(),
    ]
    
    // MARK: - Registration

    /// Do not override or add other initializers
    @objc override private init() {
        super.init()
        registerTasks()
    }
    
    private func registerTasks() {
        for task in tasks {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: task.identifier,
                using: nil,
                launchHandler: newBGTask(for: task)
            )
        }
    }
    
    private func newBGTask(for task: ThreemaBackgroundTask) -> (BGTask) -> Void {
        { [weak self] bgTask in
            DDLogNotice("\(task.identifier) started")
            
            // Directly schedule the task again, if requested
            if task.shouldReschedule {
                self?.scheduleBGTask(for: task)
            }
            
            let newTask = Task {
                await task.run()
                
                DDLogNotice("\(task.identifier) completed success=\(!Task.isCancelled)")
                bgTask.setTaskCompleted(success: !Task.isCancelled)
            }
            
            bgTask.expirationHandler = {
                DDLogNotice("\(task.identifier) expired")
                newTask.cancel()
            }
        }
    }
    
    // MARK: Scheduling
    
    /// Schedules BGTasks
    @objc public func scheduleTasks() {
        for task in tasks {
            scheduleBGTask(for: task)
        }
    }
    
    private func scheduleBGTask(for task: ThreemaBackgroundTask) {
        guard task.shouldSchedule else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: task.identifier)
            DDLogNotice("\(task.identifier) not scheduled")
            return
        }
        
        let earliestBeginDate = Date.now.addingTimeInterval(task.minimalInterval)
        let request = BGProcessingTaskRequest(identifier: task.identifier)
        request.earliestBeginDate = earliestBeginDate
        
        do {
            // Submitting a task request with the same identifier as an existing request will replace that request. Like
            // this we indirectly refresh the earliest execution date of the task.
            try BGTaskScheduler.shared.submit(request)
            
            DDLogNotice(
                "\(task.identifier) scheduled with earliest date: \(DateFormatter.shortStyleDateTimeSeconds(earliestBeginDate))"
            )
        }
        catch {
            DDLogNotice("\(task.identifier) scheduling failed: \(error)")
        }
    }
}
