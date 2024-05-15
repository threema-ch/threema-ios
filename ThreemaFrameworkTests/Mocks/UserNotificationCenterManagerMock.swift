//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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
import PromiseKit
@testable import ThreemaFramework

class UserNotificationCenterManagerMock: UserNotificationCenterManagerProtocol {
    private let returnFireDate: Date
    private let deliveredNotifications: [PendingUserNotificationKey]?

    var addCalls = [PendingUserNotificationKey]()
    var removeCalls = [PendingUserNotificationKey]()

    convenience init() {
        self.init(returnFireDate: Date())
    }

    required init(returnFireDate: Date, deliveredNotifications: [PendingUserNotificationKey]? = nil) {
        self.returnFireDate = returnFireDate
        self.deliveredNotifications = deliveredNotifications
    }
    
    func add(
        contentKey: PendingUserNotificationKey,
        stage: UserNotificationStage,
        notification: UNNotificationContent
    ) -> Promise<Date?> {
        addCalls.append(contentKey)

        return Promise { seal in
            seal.fulfill(returnFireDate)
        }
    }
    
    func isPending(contentKey: PendingUserNotificationKey, stage: UserNotificationStage) -> Bool {
        false
    }
    
    func isDelivered(contentKey: PendingUserNotificationKey) -> Bool {
        deliveredNotifications?.contains(contentKey) ?? false
    }

    func remove(contentKey: PendingUserNotificationKey, exceptStage: UserNotificationStage?, justPending: Bool) {
        removeCalls.append(contentKey)
    }
}
