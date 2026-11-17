import CocoaLumberjackSwift
import Foundation
import libthreemaSwift
import ThreemaProtocols

extension PushSetting {
    mutating func update(syncContact: D2dSync_Contact) {
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

    mutating func update(syncGroup: D2dSync_Group) {
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

    mutating func update(with contact: LibthreemaContact) {
        update(with: contact.notificationTriggerPolicyOverride)
    }

    mutating func update(with contact: LibthreemaContactUpdate) {
        switch contact.notificationTriggerPolicyOverride {
        case .remove:
            update(with: nil)
        case .unchanged:
            break
        case let .update(policy):
            update(with: policy)
        }
    }

    /// Like `update(syncGroup:)`: notifications are off while the override applies, and `mentioned` tells
    /// whether a mention still notifies.
    mutating func update(with group: LibthreemaGroup) {
        guard let policy = group.notificationTriggerPolicyOverride else {
            updatePeriodOffTillDate(nil)
            type = .on
            return
        }

        if let expiresAt = policy.expiresAt?.date {
            updatePeriodOffTillDate(expiresAt)
            type = .offPeriod
        }
        else {
            updatePeriodOffTillDate(nil)
            type = .off
        }

        switch policy.policy {
        case .mentioned:
            mentioned = true
        case .never:
            mentioned = false
        }
    }

    private mutating func update(with policy: ContactNotificationTriggerPolicyOverride?) {
        guard let policy else {
            updatePeriodOffTillDate(nil)
            type = .on
            return
        }

        switch policy.policy {
        case .never:
            if let expiresAt = policy.expiresAt {
                type = .offPeriod
                updatePeriodOffTillDate(expiresAt.date)
            }
            else {
                type = .off
                updatePeriodOffTillDate(nil)
            }
        }
    }
}
