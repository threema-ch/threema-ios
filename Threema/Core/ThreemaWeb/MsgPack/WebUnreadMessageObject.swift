//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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

import UIKit

class WebUnreadMessageObject: NSObject {
    var type: String
    var id: String
    var date: Int
    var sortKey: Int
    var isOutbox: Bool
    var isStatus = false
    var statusType: String?
    var unread: Bool?
    
    init(firstUnreadMessage: BaseMessage) {
        self.type = "contact"
        self.id = "unreadMessage"
        let currentDate = firstUnreadMessage.displayDate
        self.date = Int(currentDate.timeIntervalSince1970) - 1
        self.sortKey = Int(currentDate.timeIntervalSince1970) - 1
        self.isOutbox = true
        self.isStatus = true
        self.unread = true
        self.statusType = "firstUnreadMessage"
    }
    
    func objectDict() -> [String: Any] {
        [
            "type": type,
            "id": id,
            "date": date,
            "isOutbox": isOutbox,
            "isStatus": isStatus,
            "statusType": statusType!,
            "unread": unread!,
        ]
    }
}
