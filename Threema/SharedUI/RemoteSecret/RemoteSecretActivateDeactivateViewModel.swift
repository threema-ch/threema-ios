//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

final class RemoteSecretActivateDeactivateViewModel: ObservableObject {
    
    // MARK: - Types

    enum ViewType {
        case activate
        case deactivate
        
        var title: String {
            switch self {
            case .activate:
                #localize("rs_view_activate_title")
            case .deactivate:
                #localize("rs_view_deactivate_title")
            }
        }
        
        var boxText: String {
            switch self {
            case .activate:
                #localize("rs_view_activate_box_text")
            case .deactivate:
                #localize("rs_view_deactivate_box_text")
            }
        }
    }
    
    // MARK: - Published properties

    @Published var type: ViewType
    
    lazy var createBackupButtonTitle = #localize("rs_view_create_backup_button_title")
    lazy var removeButtonTitle = #localize("rs_view_remove_data_button_title")
    lazy var notNowButtonTitle = #localize("rs_view_not_now_button_title")

    // MARK: - Lifecycle
    
    init(type: ViewType) {
        self.type = type
    }
}
