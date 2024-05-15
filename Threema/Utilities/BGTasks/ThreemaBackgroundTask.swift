//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import Foundation

/// Tasks that can be scheduled with `ThreemaBGTaskManager`
///
/// See `MessagesRetentionBackgroundTask` for a reference implementation.
///
/// Add newly created tasks to the `tasks` property in `ThreemaBGTaskManager`
protocol ThreemaBackgroundTask: Sendable {
    /// Identifier of task
    ///
    /// It should start with `ch.threema.bgtask.` and needs to be added to the `Info.plist` files.
    var identifier: String { get }
    
    /// Minimal interval between scheduling and execution
    var minimalInterval: TimeInterval { get }
    
    /// Should this task actually be scheduled (if it was scheduled before it will be canceled)
    var shouldSchedule: Bool { get }
    
    /// If the task is executed should it be schedules again (with the same `minimalInterval`)
    var shouldReschedule: Bool { get }
    
    /// Execute the task
    func run() async
}
