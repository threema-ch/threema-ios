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

import Foundation

extension StorageManagementConversationView {
    enum ActionSheetType: Int, CaseIterable {
        case messages = 0
        case files
        
        var title: String {
            switch self {
            case .messages:
                return "delete_messages".localized
            case .files:
                return "delete_media".localized
            }
        }
            
        var description: String {
            switch self {
            case .messages:
                return "delete_messages_older_than".localized
            case .files:
                return "delete_media_older_than".localized
            }
        }
    }
}
