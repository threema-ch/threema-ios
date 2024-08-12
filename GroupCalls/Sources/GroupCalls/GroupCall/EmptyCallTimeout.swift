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

import CocoaLumberjackSwift
import Foundation

/// Helper class with a task to leave an empty call after a timeout
///
/// This is needed because a detached `Task` constructed inside a `struct` cannot access `self` (i.e. the group call
/// actor or context)
///
/// From the group calls protocol (section SFU to Participant Flow): "If the user is alone in a call for more than 3
/// minute, the call should be left to save resources. The SFU will automatically drop such calls after 5 minutes but
/// this results in non-ideal UX."
class EmptyCallTimeout {
    
    /// Timeout for an empty call
    private let timeout: TimeInterval = 60 * 3 // 3 min
    
    private let groupCallActor: GroupCallActor
    private let groupCallContext: GroupCallContextProtocol
    private var timeoutTask: Task<Void, Never>?
    
    // MARK: - Lifecycle
    
    init(groupCallActor: GroupCallActor, groupCallContext: GroupCallContextProtocol) {
        self.groupCallActor = groupCallActor
        self.groupCallContext = groupCallContext
    }
    
    deinit {
        DDLogNotice("[GroupCall] Cancel empty call timeout task during deallocation")
        timeoutTask?.cancel()
    }
    
    // MARK: - Interface
    
    /// Start timeout if not already running
    ///
    /// This will leave the call after the timeout if no new participants were added in the meantime.
    func start() {
        guard timeoutTask == nil else {
            DDLogWarn("[GroupCall] Empty call timeout task already running")
            return
        }
        
        DDLogNotice("[GroupCall] Start empty call timeout task")
        
        timeoutTask = Task.detached {
            defer {
                self.timeoutTask = nil
            }
            
            do {
                try await Task.sleep(seconds: self.timeout)
            }
            catch {
                DDLogNotice("[GroupCall] Task was cancelled while asleep: \(error)")
                return
            }
            
            // Check if call is still empty
            guard await !self.groupCallContext.hasAnyParticipants else {
                DDLogNotice("[GroupCall] Group call doesn't seem empty anymore. Cancel leave task")
                return
            }
            
            DDLogNotice("[GroupCall] Leave empty call after \(self.timeout) seconds")
            await self.groupCallActor.beginLeaveCall()
        }
    }
    
    /// Cancel timeout
    func cancel() {
        guard timeoutTask != nil else {
            // Nothing to cancel
            return
        }
        
        DDLogNotice("[GroupCall] Cancel empty call timeout task")
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}
