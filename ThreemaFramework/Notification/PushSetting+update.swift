//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import ThreemaProtocols

extension PushSetting {
    mutating func update(syncContact: Sync_Contact) {
        if syncContact.hasNotificationSoundPolicyOverride {
            switch syncContact.notificationSoundPolicyOverride.override {
            case .default:
                muted = false
            case .policy(.muted):
                muted = true
            case .policy(.UNRECOGNIZED(_)):
                DDLogError("Unknown type of notification sound policy")
            case .none:
                break
            }
        }

        if syncContact.hasNotificationTriggerPolicyOverride {
            switch syncContact.notificationTriggerPolicyOverride.override {
            case .default:
                updatePeriodOffTillDate(nil)
                type = .on
            case let .policy(triggerPolicy):
                if triggerPolicy.hasExpiresAt, let date = triggerPolicy.expiresAt.date {
                    updatePeriodOffTillDate(date)
                    type = .offPeriod
                }
                else {
                    switch triggerPolicy.policy {
                    case .never:
                        updatePeriodOffTillDate(nil)
                        type = .off
                    case .UNRECOGNIZED:
                        DDLogError("Unknown type of notification trigger policy")
                    }
                }
            case .none:
                break
            }
        }
    }

    mutating func update(syncGroup: Sync_Group) {
        if syncGroup.hasNotificationSoundPolicyOverride {
            switch syncGroup.notificationSoundPolicyOverride.override {
            case .default:
                muted = false
            case .policy(.muted):
                muted = true
            case .policy(.UNRECOGNIZED(_)):
                DDLogError("Unknown type of notification sound policy")
            case .none:
                break
            }
        }

        if syncGroup.hasNotificationTriggerPolicyOverride {
            switch syncGroup.notificationTriggerPolicyOverride.override {
            case .default:
                updatePeriodOffTillDate(nil)
                type = .on
            case let .policy(triggerPolicy):
                if triggerPolicy.hasExpiresAt, let date = triggerPolicy.expiresAt.date {
                    updatePeriodOffTillDate(date)
                    type = .offPeriod
                }
                else {
                    type = .off
                }

                switch triggerPolicy.policy {
                case .never:
                    mentioned = false
                case .mentioned:
                    mentioned = true
                case .UNRECOGNIZED:
                    DDLogError("Unknown type of notification trigger policy")
                }
            case .none:
                break
            }
        }
    }
}
