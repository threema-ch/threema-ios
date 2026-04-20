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
