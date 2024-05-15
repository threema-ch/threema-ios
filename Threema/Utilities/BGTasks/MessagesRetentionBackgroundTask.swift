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

/// Run message retention periodically in the background
struct MessagesRetentionBackgroundTask: ThreemaBackgroundTask {
    let identifier = "ch.threema.bgtask.messageRetention"
    let minimalInterval: TimeInterval = 43200 // 12h
    
    // Only schedule if message retention is enabled
    var shouldSchedule: Bool {
        let mdmDays = MDMSetup(setup: false).keepMessagesDays() ?? 0
        
        return mdmDays.intValue > 0 || UserSettings.shared().keepMessagesDays > 0
    }
    
    // We directly schedule the task again, so we are not dependent on an app launch
    let shouldReschedule = true
    
    func run() async {
        let businessInjector = BusinessInjector(forBackgroundProcess: true)
        
        await businessInjector.messageRetentionManager.deleteOldMessages()
        
        // We must call disconnect explicitly, since we do not run through one of the app delegate methods when the
        // task completes.
        businessInjector.serverConnector.disconnectWait(initiator: .app)
    }
}
