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

extension ProfileCollectionViewDataSource {
    enum Section {
        case header
        case safe
        case idExport
        case linking
        case publicKey
        case revokeDelete
        
        var rows: [Row] {
            switch self {
            case .header:
                [.header]
            case .safe:
                [.threemaSafe]
            case .idExport:
                if TargetManager.isOnPrem {
                    [.idExport]
                }
                else {
                    [.idExport, .revocationPassword]
                }
            case .linking:
                [.phone, .mail]
            case .publicKey:
                [.publicKey]
            case .revokeDelete:
                [.revokeDelete]
            }
        }
        
        var footerText: String? {
            let mdm = MDMSetup(setup: false)

            switch self {
            case .header:
                return nil
                
            case .safe:
                if mdm?.isSafeBackupDisable() ?? false {
                    return #localize("disabled_by_device_policy")
                }
                else {
                    return String.localizedStringWithFormat(
                        #localize("safe_enable_explain_short"),
                        TargetManager.localizedAppName
                    )
                }
                
            case .idExport:
                if (mdm?.disableBackups() ?? false) || (mdm?.disableIDExport() ?? false) ||
                    (mdm?.readonlyProfile() ?? false) {
                    return #localize("disabled_by_device_policy")
                }
                else {
                    return nil
                }
                
            case .linking:
                return String(format: #localize("myprofile_link_email_phone_footer"), TargetManager.appName)

            case .publicKey:
                return nil

            case .revokeDelete:
                if mdm?.readonlyProfile() ?? false {
                    return #localize("disabled_by_device_policy")
                }
                else {
                    return nil
                }
            }
        }
    }
    
    enum Row {
        case header
                
        case threemaSafe
        
        case idExport
        case revocationPassword
        
        case phone
        case mail
        
        case publicKey
        
        case revokeDelete
        
        var title: String? {
            switch self {
            case .header:
                nil
            case .threemaSafe:
                String.localizedStringWithFormat(
                    #localize("safe_setup_backup_title"),
                    TargetManager.localizedAppName
                )
            case .idExport:
                #localize("profile_id_export")
            case .revocationPassword:
                #localize("revocation_password")
            case .phone:
                #localize("profile_linked_phone")
            case .mail:
                #localize("profile_linked_email")
            case .publicKey:
                #localize("public_key")
            case .revokeDelete:
                #localize("my_profile_delete_cell_title")
            }
        }
        
        var accessoryText: String? {
            let businessInjector = BusinessInjector.ui
            
            switch self {
            case .header:
                return nil

            case .threemaSafe:
                let safeManager = SafeManager(
                    safeConfigManager: SafeConfigManager(),
                    safeStore: SafeStore(
                        safeConfigManager: SafeConfigManager(),
                        serverApiConnector: ServerAPIConnector(),
                        groupManager: businessInjector.groupManager
                    ),
                    safeApiService: SafeApiService()
                )
                return safeManager.isActivated ? #localize("On") : #localize("Off")

            case .idExport:
                return nil
                
            case .revocationPassword:
                if let date = businessInjector.myIdentityStore.revocationPasswordSetDate {
                    return DateFormatter.getShortDate(date)
                }
                else {
                    return #localize("revocation_password_not_set")
                }

            case .phone:
                if businessInjector.myIdentityStore.linkMobileNoPending {
                    return #localize("enter_code")
                }
                else if let linkedMobile = businessInjector.myIdentityStore.linkedMobileNo {
                    return "+\(linkedMobile)"
                }
                else {
                    return nil
                }
     
            case .mail:
                if businessInjector.myIdentityStore.linkEmailPending {
                    return #localize("(pending)")
                }
                else if let linkedEmail = businessInjector.myIdentityStore.linkedEmail {
                    return linkedEmail
                }
                else {
                    return nil
                }
                
            case .publicKey:
                return nil
                
            case .revokeDelete:
                return nil
            }
        }

        var isInteractionDisabled: Bool {
            let mdm = MDMSetup(setup: false)

            switch self {
            case .header, .publicKey:
                return false
            case .threemaSafe:
                return mdm?.isSafeBackupDisable() ?? false
            case .idExport:
                return (mdm?.disableBackups() ?? false) || (mdm?.disableIDExport() ?? false)
            case .revocationPassword, .phone, .mail, .revokeDelete:
                return mdm?.readonlyProfile() ?? false
            }
        }
        
        static func row(for destination: ProfileCoordinator.InternalDestination) -> Self? {
            switch destination {
            case .qrCode:
                nil
            case .shareID:
                nil
            case .threemaSafe:
                .threemaSafe
            case .idExport:
                .idExport
            case .revocationPassword:
                .revocationPassword
            case .linkPhone:
                .phone
            case .linkMail:
                .mail
            case .publicKey:
                .publicKey
            case .revokeDelete:
                .revokeDelete
            }
        }
    }
}
