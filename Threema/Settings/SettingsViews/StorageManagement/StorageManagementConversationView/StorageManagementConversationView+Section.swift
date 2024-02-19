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
    enum Section: Hashable, CaseIterable, Identifiable {
        var id: Self { self }
        
        case messages
        case files
        case messageRetention
        
        var localizedTitle: String {
            switch self {
            case .messages:
                return "messages".localized
            case .files:
                return "files".localized
            case .messageRetention:
                return "automatic_delete".localized
            }
        }
        
        var localizedDescription: String {
            switch self {
            case .messages:
                return "delete_messages_explain".localized
            case .files:
                return "delete_explain".localized
            case .messageRetention:
                return "automatic_delete_explain".localized
            }
        }
        
        var symbol: String {
            switch self {
            case .messages:
                return "envelope"
            case .files:
                return "doc"
            case .messageRetention:
                return "xmark.bin"
            }
        }
    }
}
