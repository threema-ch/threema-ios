//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

extension StorageManagementConversationView {
    enum OlderThanOption: Identifiable, Equatable, Hashable {
        static var allDeleteCases: [OlderThanOption] {
            commonCases + [.everything]
        }
        
        static var allRetentionCases: [OlderThanOption] {
            commonCases.reversed() + [.forever]
        }
        
        static var commonCases: [OlderThanOption] {
            [.oneYear, .sixMonths, .threeMonths, .oneMonth, .oneWeek]
        }

        public var id: Self { self }
        
        case oneYear
        case sixMonths
        case threeMonths
        case oneMonth
        case oneWeek
        /// is not a valid case for message retention
        case everything
        case forever
        
        /// This is used for custom days settings by mdm.
        case custom(_ days: Int)
        
        static func retentionOption(from days: Int) -> OlderThanOption {
            if let option = OlderThanOption.allRetentionCases.first(where: { $0.days == days }) {
                option
            }
            else {
                .custom(days)
            }
        }
        
        var days: Int? {
            guard let date else {
                return self == .forever ? -1 : nil
            }
            return Calendar.current.dateComponents([.day], from: date, to: Date.currentDate).day
        }
        
        var date: Date? {
            let calendar = Calendar.current
            let now = Date.currentDate
            
            switch self {
            case .oneYear:
                return calendar.date(byAdding: .year, value: -1, to: now)
            case .sixMonths:
                return calendar.date(byAdding: .month, value: -6, to: now)
            case .threeMonths:
                return calendar.date(byAdding: .month, value: -3, to: now)
            case .oneMonth:
                return calendar.date(byAdding: .month, value: -1, to: now)
            case .oneWeek:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .everything:
                return nil
            case .forever:
                return nil
            case let .custom(days):
                return calendar.date(byAdding: .day, value: -days, to: now)
            }
        }
        
        var localizedTitleDescription: String {
            switch self {
            case .oneYear:
                "one_year_title".localized
            case .sixMonths:
                "six_months_title".localized
            case .threeMonths:
                "three_months_title".localized
            case .oneMonth:
                "one_month_title".localized
            case .oneWeek:
                "one_week_title".localized
            case .everything:
                "everything".localized
            case .forever:
                "forever".localized
            case let .custom(days) where days <= 0: // MDM Setting
                "forever".localized
            case let .custom(days): // MDM Setting
                String.localizedStringWithFormat(
                    "number_of_days".localized,
                    days
                )
            }
        }
        
        var localizedDescription: String {
            switch self {
            case .oneYear:
                "one_year".localized
            case .sixMonths:
                "six_months".localized
            case .threeMonths:
                "three_months".localized
            case .oneMonth:
                "one_month".localized
            case .oneWeek:
                "one_week".localized
            case .everything:
                "everything".localized
            case .forever:
                "forever".localized
            case .custom:
                ""
            }
        }
        
        var deleteMessageConfirmationSentence: String {
            switch self {
            case .oneYear, .sixMonths, .threeMonths, .oneMonth, .oneWeek:
                let defaultString = "delete_messages_confirm".localized
                return String.localizedStringWithFormat(defaultString, localizedDescription)
            case .everything:
                return "delete_messages_confirm_all".localized
            default:
                return ""
            }
        }
        
        var deleteMediaConfirmationSentence: String {
            switch self {
            case .oneYear, .sixMonths, .threeMonths, .oneMonth, .oneWeek:
                let defaultString = "delete_media_confirm".localized
                return String.localizedStringWithFormat(defaultString, localizedDescription)
            case .everything:
                return "delete_media_confirm_all".localized
            default:
                return ""
            }
        }
    }
}
