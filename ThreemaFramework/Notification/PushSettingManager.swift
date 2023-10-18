//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

import Foundation

public class PushSettingManager {
    
    private typealias TimeOfDay = (hour: Int, minute: Int)

    private let userSettings: UserSettingsProtocol
    private let isWorkApp: Bool
    
    public init(_ userSettings: UserSettingsProtocol, _ isWorkApp: Bool) {
        self.userSettings = userSettings
        self.isWorkApp = isWorkApp
    }
    
    public func find(forConversation: Conversation) -> PushSetting? {
        let id: String?
        if forConversation.isGroup() {
            id = forConversation.groupID?.hexString
        }
        else {
            id = forConversation.contact?.identity
        }
        return find(forID: id ?? "")
    }
    
    func find(forIdentity: String) -> PushSetting? {
        find(forID: forIdentity)
    }
    
    public func canMasterDndSendPush() -> Bool {
        if isWorkApp {
            if userSettings.enableMasterDnd {
                let calendar = Calendar.current
                let currentDate = Date()
                let currentWeekDay = calendar.component(.weekday, from: currentDate)
                
                if let selectedWorkingDays = userSettings.masterDndWorkingDays,
                   selectedWorkingDays.contains(currentWeekDay) {
                    
                    let currentTime = TimeOfDay(
                        hour: calendar.component(.hour, from: currentDate),
                        minute: calendar.component(.minute, from: currentDate)
                    )
                    let startTime = timeOfDayFromTimeString(timeString: userSettings.masterDndStartTime)
                    let endTime = timeOfDayFromTimeString(timeString: userSettings.masterDndEndTime)
                    
                    if currentTime >= startTime, currentTime <= endTime {
                        return true
                    }
                }
                return false
            }
        }
        
        return true
    }

    private func find(forID: String) -> PushSetting? {
        let pushSettings = userSettings.pushSettingsList.filtered(using: NSPredicate(format: "identity == %@", forID))
        // swiftformat:disable:next isEmpty
        if pushSettings.count > 0 {
            return PushSetting(dictionary: pushSettings.firstObject as? [AnyHashable: Any])
        }
        return nil
    }
    
    private func timeOfDayFromTimeString(timeString: String) -> TimeOfDay {
        let components: [String] = timeString.components(separatedBy: ":")
        return TimeOfDay(hour: Int(components[0])!, minute: Int(components[1])!)
    }
}
