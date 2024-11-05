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
import ThreemaMacros

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
                #localize("one_year_title")
            case .sixMonths:
                #localize("six_months_title")
            case .threeMonths:
                #localize("three_months_title")
            case .oneMonth:
                #localize("one_month_title")
            case .oneWeek:
                #localize("one_week_title")
            case .everything:
                #localize("everything")
            case .forever:
                #localize("forever")
            case let .custom(days) where days <= 0: // MDM Setting
                #localize("forever")
            case let .custom(days): // MDM Setting
                String.localizedStringWithFormat(
                    #localize("number_of_days"),
                    days
                )
            }
        }
        
        var localizedDescription: String {
            switch self {
            case .oneYear:
                #localize("one_year")
            case .sixMonths:
                #localize("six_months")
            case .threeMonths:
                #localize("three_months")
            case .oneMonth:
                #localize("one_month")
            case .oneWeek:
                #localize("one_week")
            case .everything:
                #localize("everything")
            case .forever:
                #localize("forever")
            case .custom:
                ""
            }
        }
        
        var deleteMessageConfirmationSentence: String {
            switch self {
            case .oneYear, .sixMonths, .threeMonths, .oneMonth, .oneWeek:
                let defaultString = #localize("delete_messages_confirm")
                return String.localizedStringWithFormat(defaultString, localizedDescription)
            case .everything:
                return #localize("delete_messages_confirm_all")
            default:
                return ""
            }
        }
        
        var deleteMediaConfirmationSentence: String {
            switch self {
            case .oneYear, .sixMonths, .threeMonths, .oneMonth, .oneWeek:
                let defaultString = #localize("delete_media_confirm")
                return String.localizedStringWithFormat(defaultString, localizedDescription)
            case .everything:
                return #localize("delete_media_confirm_all")
            default:
                return ""
            }
        }
    }
}
