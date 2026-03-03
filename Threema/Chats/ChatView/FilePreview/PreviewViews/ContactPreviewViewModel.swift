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

import Combine
import Contacts
import ThreemaFramework
import ThreemaMacros

final class ContactPreviewViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var showAlert = false
    
    let fileMessageEntity: FileMessageEntity
    let authorizationStatus: (CNEntityType) -> CNAuthorizationStatus
    let requestContactAccess: (CNEntityType) async throws -> Bool
    
    private(set) lazy var alertTitle = #localize("alert_no_access_title_contacts")
    private(set) lazy var alertMessage = #localize("alert_no_access_message_contacts")
    private(set) lazy var alertOpenSettingsButtonTitle = #localize("alert_no_access_open_settings")
    private(set) lazy var alertCancelButtonTitle = #localize("cancel")

    init(
        fileMessageEntity: FileMessageEntity,
        authorizationStatus: @escaping (CNEntityType) -> CNAuthorizationStatus,
        requestContactAccess: @escaping (CNEntityType) async throws -> Bool
    ) {
        self.fileMessageEntity = fileMessageEntity
        self.authorizationStatus = authorizationStatus
        self.requestContactAccess = requestContactAccess
    }

    func checkContactAccess() {
        let status = authorizationStatus(.contacts)

        if #available(iOS 18.0, *) {
            isAuthorized = status == .authorized || status == .limited
        }
        else {
            isAuthorized = status == .authorized
        }

        guard !isAuthorized else {
            return
        }
        
        Task { [weak self] in
            guard let self else {
                return
            }
            
            do {
                let granted = try await requestContactAccess(.contacts)
                
                if granted {
                    isAuthorized = true
                }
                else {
                    showAlert = true
                }
            }
            catch {
                showAlert = true
            }
        }
    }
    
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        UIApplication.shared.open(url)
    }
}
