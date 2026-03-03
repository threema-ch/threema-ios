//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import Collections
import Foundation

/// Due to having asynchronicity setting up the business during setup, we have to postpone some work from various
/// delegate methods called in `AppDelegate` to the point when the business is initialized.
@objc final class LaunchTaskManager: NSObject {
    
    // Note: Using a `Deque` is most likely overkill for this situation. According to benchmarks, it only is more
    // efficient than an Array the item count reaches approximately 32 elements.
    private var deque = Deque<LaunchTaskItem>()
    
    // MARK: - Lifecycle
    
    @objc override init() { }
    
    // MARK: - Task creation
    
    /// Adds a task to the queue that will be run when calling `runTasks()`
    /// - Parameter task: Code to be run
    func add(_ task: @escaping () -> Void) {
        let item = LaunchTaskItem(task: task)
        deque.append(item)
    }
    
    // MARK: - Task running
    
    /// Runs all the task in the queue in the order they were added.
    @objc func runTasks() {
        while let task = deque.popFirst() {
            task.run()
        }
    }
}

private struct LaunchTaskItem {
    
    // MARK: - Properties
    
    let task: () -> Void
    
    // MARK: - Lifecycle
    
    init(task: @escaping () -> Void) {
        self.task = task
    }
    
    // MARK: - Functions
    
    func run() {
        task()
    }
}
