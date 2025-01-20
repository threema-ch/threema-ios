//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
import ThreemaEssentials
import ThreemaMacros

public struct PushSetting: Codable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case identity, groupIdentity, _type, muted, mentioned, periodOffTillDate
    }

    public enum PushSettingType: Int, Codable, Sendable {
        /// Notifications are on (i.e. DND is off)
        case on = 0
        /// Notifications are disabled indefinitely (i.e. DND is on)
        case off = 1
        /// Notifications are disabled for a certain period
        case offPeriod = 2
    }

    /// Set of possible off-periods
    ///
    /// Identical on all platforms supported by Threema.
    public enum PeriodOffTime: Int, CaseIterable, Codable, Equatable {
        case time1Hour = 0
        case time2Hours = 1
        case time3Hours = 2
        case time4Hours = 3
        case time8Hours = 4
        case time1Day = 5
        case time1Week = 6

        public var localizedString: String {
            switch self {
            case .time1Hour:
                #localize("doNotDisturb_onPeriod_1Hour")
            case .time2Hours:
                #localize("doNotDisturb_onPeriod_2Hours")
            case .time3Hours:
                #localize("doNotDisturb_onPeriod_3Hours")
            case .time4Hours:
                #localize("doNotDisturb_onPeriod_4Hours")
            case .time8Hours:
                #localize("doNotDisturb_onPeriod_8Hours")
            case .time1Day:
                #localize("doNotDisturb_onPeriod_1Day")
            case .time1Week:
                #localize("doNotDisturb_onPeriod_1Week")
            }
        }
    }

    init(identity: ThreemaIdentity) {
        self.init(identity: identity, groupIdentity: nil)
    }

    init(groupIdentity: GroupIdentity) {
        self.init(identity: nil, groupIdentity: groupIdentity)
    }

    init(
        identity: ThreemaIdentity?,
        groupIdentity: GroupIdentity?,
        _type: PushSettingType = .on,
        periodOffTillDate: Date? = nil,
        muted: Bool = false,
        mentioned: Bool = false
    ) {
        self.identity = identity
        self.groupIdentity = groupIdentity
        self._type = _type
        self.periodOffTillDate = periodOffTillDate
        self.muted = muted
        self.mentioned = mentioned
    }

    public private(set) var identity: ThreemaIdentity?

    public private(set) var groupIdentity: GroupIdentity?

    private var _type: PushSettingType

    /// "State" of this setting
    ///
    /// If it is `PushSettingType.offPeriod`, but `periodOffTillDate` is `nil` or in the past it will automatically
    /// reset to `PushSettingType.on` on reading.
    ///
    /// When setting this to `PushSettingType.offPeriod` always set `setPeriodOffTime` before reading this value.
    /// (Otherwise it will reset to `PushSettingType.on`.)
    public var type: PushSettingType {
        mutating get {
            updatePeriodOffTillDateIsExpired()

            return _type
        }

        mutating set {
            _type = newValue
        }
    }

    /// Period of off-time
    ///
    /// When set automatically sets `periodOffTillDate` to the date in the future with this period.
    /// - Parameter duration: Duration who long notifying is off
    public mutating func setPeriodOffTime(_ duration: PeriodOffTime) {
        // Automatically set expiration date
        switch duration {
        case .time1Hour:
            periodOffTillDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        case .time2Hours:
            periodOffTillDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())
        case .time3Hours:
            periodOffTillDate = Calendar.current.date(byAdding: .hour, value: 3, to: Date())
        case .time4Hours:
            periodOffTillDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())
        case .time8Hours:
            periodOffTillDate = Calendar.current.date(byAdding: .hour, value: 8, to: Date())
        case .time1Day:
            periodOffTillDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        case .time1Week:
            periodOffTillDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        }
    }

    /// When does the current off-period end?
    public var periodOffTillDate: Date? = nil

    /// Housekeeping: Ensure that `type` is only `PushSettingType.offPeriod` if a `periodOffTillDate`
    /// is set and it is in the future
    ///
    /// - Returns: True when `PushSetting` has changed
    @discardableResult mutating func updatePeriodOffTillDateIsExpired() -> Bool {
        if _type == .offPeriod {
            if periodOffTillDate == nil {
                _type = .on

                return true
            }
            // This should be the only needed date comparison in all of this struct
            else if periodOffTillDate?.compare(.now) == .orderedAscending {
                _type = .on
                periodOffTillDate = nil

                return true
            }
        }

        return false
    }

    /// Update `periodOffTillDate`
    ///
    /// - Parameter date: Date is till date or `nil` for `on` and `off`
    mutating func updatePeriodOffTillDate(_ date: Date?) {
        periodOffTillDate = date
    }

    /// Should a notification sound be played?
    public var muted: Bool

    /// Should notifications always be shown if I mentioned?
    public var mentioned: Bool

    /// Localized description of current state to show in UI
    public var localizedDescription: String {
        let formatString = #localize("doNotDisturb_on_until_date_and_time")

        return localizedDescription(offPeriodFormatString: formatString)
    }

    /// Longer localized description of current state to show in UI
    public var localizedLongDescription: String {
        let formatString = #localize("doNotDisturb_on_until_date_and_time_long")

        return localizedDescription(offPeriodFormatString: formatString)
    }

    /// Helper for the previous two getters
    /// This method should always be internal and a caller has to ensure that `offPeriodFormatString` is
    /// not controllable by the user or any remote user, because it is a format string.
    private func localizedDescription(offPeriodFormatString: String) -> String {
        var pushSetting = self
        switch pushSetting.type {
        case .offPeriod:
            if let periodOffTillDate {
                let formattedDateAndTime = DateFormatter.relativeLongStyleDateShortStyleTime(periodOffTillDate)
                return String(format: offPeriodFormatString, formattedDateAndTime)
            }
            else {
                return ""
            }
        case .off:
            return #localize("doNotDisturb_on")
        case .on:
            return #localize("doNotDisturb_off")
        }
    }

    /// SF Symbol name for current push setting
    public var sfSymbolNameForPushSetting: String {
        guard let sfSymbolName = sfSymbolNameForEditedPushSetting else {
            return "bell.fill"
        }
        return sfSymbolName
    }

    /// SF Symbol name for current push setting if setting is not set to the defaults
    var sfSymbolNameForEditedPushSetting: String? {
        var sfSymbolName: String? = nil

        var pushSetting = self
        if !mentioned, pushSetting.type == .offPeriod || pushSetting.type == .off {
            sfSymbolName = "minus.circle.fill"
        }
        else if mentioned, pushSetting.type == .offPeriod || pushSetting.type == .off {
            sfSymbolName = "at.circle.fill"
        }
        else if muted, pushSetting.type == .on {
            sfSymbolName = "bell.slash.fill"
        }

        return sfSymbolName
    }

    /// Should we show a notification for this GroupCallStartMessage message?
    func canSendPushGroupCallStartMessage(for message: AbstractMessage?) -> Bool {
        var pushSetting = self
        if pushSetting.type == .offPeriod || pushSetting.type == .off {
            if !mentioned, message is GroupCallStartMessage {
                return false
            }
        }
        return true
    }

    /// Should a notification be shown according to this setting?
    public func canSendPush() -> Bool {
        var pushSetting = self
        if pushSetting.type == .offPeriod || pushSetting.type == .off {
            return false
        }
        return true
    }

    /// Icon to represent the current setting
    func imageForPushSetting() -> UIImage? {
        guard let pushSettingIcon = imageForEditedPushSetting() else {
            return UIImage(named: "bell.fill")
        }
        return pushSettingIcon
    }

    /// Icon to display if setting is not set to the defaults
    public func imageForEditedPushSetting(with config: UIImage.Configuration? = nil) -> UIImage? {
        var pushSettingIcon: UIImage? = nil

        var pushSetting = self
        if !mentioned, pushSetting.type == .offPeriod || pushSetting.type == .off {
            pushSettingIcon = UIImage(systemName: "minus.circle.fill", withConfiguration: config)
        }
        else if mentioned, pushSetting.type == .offPeriod || pushSetting.type == .off {
            pushSettingIcon = UIImage(systemName: "at.circle.fill", withConfiguration: config)
        }
        else if pushSetting.type == .on, muted {
            pushSettingIcon = UIImage(systemName: "bell.slash.circle.fill", withConfiguration: config)
        }

        return pushSettingIcon
    }
}
