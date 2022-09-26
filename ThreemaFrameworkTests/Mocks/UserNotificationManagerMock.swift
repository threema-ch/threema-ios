//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
@testable import ThreemaFramework

class UserNotificationManagerMock: UserNotificationManagerProtocol {
    
    private var returnUserNotificationContent: UserNotificationContent?
    
    convenience init(returnUserNotificationContent: UserNotificationContent) {
        self.init()
        self.returnUserNotificationContent = returnUserNotificationContent
    }
        
    func userNotificationContent(_ pendingUserNotification: PendingUserNotification) -> UserNotificationContent? {
        returnUserNotificationContent
    }
    
    func testNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent {
        UNMutableNotificationContent()
    }
    
    func threemaWebNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = BundleUtil.localizedString(forKey: "notification.threemaweb.connect.title")
        notificationContent.body = BundleUtil.localizedString(forKey: "notification.threemaweb.connect.body")
        notificationContent.userInfo = payload

        return notificationContent
    }
    
    func applyContent(
        _ from: UserNotificationContent,
        _ to: inout UNMutableNotificationContent,
        _ silent: Bool,
        _ baseMessage: BaseMessage?
    ) { }
}
