import Foundation
import ThreemaMacros

extension ProfileCollectionViewDataSource {
    enum Section {
        case header
        case backups
        case id
        case linking
        case publicKey
        case revokeDelete
        
        var rows: [Row] {
            switch self {
            case .header:
                [.header]
            case .backups:
                [.backups]
            case .id:
                TargetManager.isOnPrem ? [] : [.revocationPassword]
            case .linking:
                [.phone, .mail]
            case .publicKey:
                [.publicKey]
            case .revokeDelete:
                [.revokeDelete]
            }
        }
        
        var footerText: String? {
            guard let mdm = MDMSetup() else {
                assertionFailure("MDMSetup should always be available")
                return nil
            }

            switch self {
            case .header:
                return nil
                
            case .backups:
                if mdm.disableBackups() {
                    return #localize("disabled_by_device_policy")
                }
                else {
                    return #localize("backups_explain_short")
                }

            case .id:
                if mdm.disableBackups() || mdm.disableIDExport() || mdm.readonlyProfile() {
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
                if mdm.readonlyProfile() {
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
                
        case backups

        case revocationPassword
        
        case phone
        
        case mail
        
        case publicKey
        
        case revokeDelete
        
        var title: String? {
            switch self {
            case .header:
                nil
            case .backups:
                #localize("backups")
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

            case .backups:
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
        
        var isDestructive: Bool {
            self == .revokeDelete
        }
        
        var isInteractionDisabled: Bool {
            guard let mdm = MDMSetup() else {
                assertionFailure("MDMSetup should always be available")
                return false
            }

            switch self {
            case .header, .publicKey:
                return false

            case .backups:
                return mdm.disableBackups()

            case .revocationPassword, .phone, .mail, .revokeDelete:
                return mdm.readonlyProfile()
            }
        }
        
        static func row(for destination: ProfileCoordinator.InternalDestination) -> Self? {
            switch destination {
            case .editProfile, .scanQRCode, .qrCode, .shareID:
                nil

            case .backups:
                .backups

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
