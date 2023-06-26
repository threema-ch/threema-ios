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

// MARK: - PeriodOffTime + CaseIterable

extension PeriodOffTime: CaseIterable {
    
    /// Get all enum cases at once
    ///
    /// Adds `CaseIterable` conformation
    public static var allCases: [PeriodOffTime] = [
        .time1Hour,
        .time2Hours,
        .time3Hours,
        .time4Hours,
        .time8Hours,
        .time1Day,
        .time1Week,
    ]
}

extension PeriodOffTime {
    
    /// Get a localized string for each `PeriodOffTime` case
    public var localizedString: String {
        switch self {
        case .time1Hour:
            return BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_1Hour")
        case .time2Hours:
            return BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_2Hours")
        case .time3Hours:
            return BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_3Hours")
        case .time4Hours:
            return BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_4Hours")
        case .time8Hours:
            return BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_8Hours")
        case .time1Day:
            return BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_1Day")
        case .time1Week:
            return BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_1Week")
        @unknown default:
            assertionFailure("Unknown off time period \(self): \(rawValue)")
            return "Unknown \(self): \(rawValue)"
        }
    }
}
