import Foundation
import ThreemaMacros

extension SettingsCollectionViewDataSource {
    
    // MARK: - Types

    enum Section {
        case dev
        case general
        case desktop
        case status
        case workAdvertising
        case workReferral
        case social
        case support
        
        var rows: [Row] {
            switch self {
            case .dev:
                var devRows: [Row] = []
                if showFeedback {
                    devRows.append(.betaFeedback)
                }
                if showDeveloper {
                    devRows.append(.developer)
                }
                return devRows
                
            case .general:
                return [.privacy, .appearance, .notifications, .chat, .media, .storage, .passcode, .calls]
            
            case .desktop:
                var desktopRows = [Row]()
                if !MDMSetup().disableMultiDevice() {
                    desktopRows.append(.desktop)
                }
                if !MDMSetup().disableWeb() {
                    desktopRows.append(.web)
                }
                return desktopRows
            
            case .status:
                var statusRows: [Row] = [.network, .version]
                if TargetManager.isBusinessApp {
                    statusRows.append(.workLicense)
                }
                if AppLaunchManager.remoteSecretManager.isRemoteSecretEnabled {
                    statusRows.append(.remoteSecretState)
                }
                return statusRows
                
            case .workAdvertising:
                if TargetManager.current == .threema {
                    return [.workAd]
                }
                else {
                    return []
                }
                
            case .workReferral:
                if TargetManager.current == .threema {
                    return [.workReferral]
                }
                else {
                    return []
                }
                
            case .social:
                var socialRows: [Row] = []
                switch TargetManager.current {
                case .threema:
                    socialRows = [.rate, .invite, .channel]
                case .work:
                    socialRows = [.rate, .channel]
                case .green, .blue:
                    break
                case .onPrem, .customOnPrem:
                    if TargetManager.rateLink != nil {
                        socialRows = [.rate]
                    }
                }
                return socialRows
                
            case .support:
                if !TargetManager.isOnPrem {
                    return [.support, .policy, .tos, .license, .advanced]
                }
                else {
                    return [.support, .license, .advanced]
                }
            }
        }
        
        private var showFeedback: Bool {
            switch ThreemaEnvironment.env() {
            case .appStore:
                false
            case .testFlight:
                if TargetManager.current == .threema || TargetManager.current == .work {
                    true
                }
                else {
                    false
                }
            case .xcode:
                true
            }
        }

        private var showDeveloper: Bool {
            switch ThreemaEnvironment.env() {
            case .appStore:
                false
            case .testFlight:
                if TargetManager.isSandbox {
                    true
                }
                else {
                    false
                }
            case .xcode:
                true
            }
        }
    }
    
    enum Row {
        case betaFeedback
        case developer
        
        case privacy
        case appearance
        case notifications
        case chat
        case media
        case storage
        case passcode
        case calls
        
        case desktop
        case web
        
        case network
        case version
        case workLicense
        case remoteSecretState
        
        case rate
        case invite
        case channel
        
        case workAd
        case workReferral
        
        case support
        case policy
        case tos
        case license
        case advanced
        
        var title: String {
            switch self {
            case .betaFeedback:
                #localize("settings_feedback")
            case .developer:
                "Developer Settings"
            case .privacy:
                #localize("settings_list_privacy_title")
            case .appearance:
                #localize("settings_list_appearance_title")
            case .notifications:
                #localize("settings_list_notifications_title")
            case .chat:
                #localize("settings_list_chat_title")
            case .media:
                #localize("settings_list_media_title")
            case .storage:
                #localize("settings_list_storage_management_title")
            case .passcode:
                #localize("settings_list_passcode_lock_title")
            case .calls:
                #localize("settings_threema_calls")
            case .desktop:
                String.localizedStringWithFormat(
                    #localize("settings_list_threema_desktop_title"),
                    TargetManager.appName
                )
            case .web:
                #localize("settings_list_threema_web_title")
            case .network:
                #localize("settings_list_network_title")
            case .version:
                #localize("settings_list_version_title")
            case .workLicense:
                #localize("settings_list_settings_license_username_title")
            case .remoteSecretState:
                #localize("settings_list_remote_secret_title")
            case .rate:
                String.localizedStringWithFormat(
                    #localize("settings_list_rate"),
                    TargetManager.appName
                )
            case .workAd:
                #localize("settings_threema_work")
            case .workReferral:
                ""
            case .invite:
                #localize("settings_list_invite_a_friend_title")
            case .channel:
                String.localizedStringWithFormat(
                    #localize("settings_list_threema_channel_title"),
                    TargetManager.localizedAppName
                )
            case .support:
                #localize("settings_list_support_title")
            case .policy:
                #localize("settings_list_privacy_policy_title")
            case .tos:
                #localize("settings_list_tos_title")
            case .license:
                #localize("settings_list_license_title")
            case .advanced:
                #localize("settings_advanced")
            }
        }
        
        var icon: UIImage? {
            switch self {
            case .betaFeedback:
                UIImage(systemName: "ant.fill")
            case .developer:
                UIImage(systemName: "pc")
            case .privacy:
                UIImage(systemName: "hand.raised.fill")
            case .appearance:
                UIImage(systemName: "paintbrush.pointed.fill")
            case .notifications:
                UIImage(systemName: "app.badge.fill")
            case .chat:
                UIImage(systemName: "bubble.left.and.bubble.right.fill")
            case .media:
                UIImage(systemName: "photo.on.rectangle.angled")
            case .storage:
                UIImage(systemName: "externaldrive.fill")
            case .passcode:
                UIImage(systemName: "lock.fill")
            case .calls:
                UIImage(resource: .threemaPhoneFill)
            case .desktop:
                UIImage(systemName: "desktopcomputer")
            case .web:
                UIImage(systemName: "menubar.dock.rectangle")
            case .network, .version, .workLicense, .workAd, .workReferral, .remoteSecretState:
                nil
            case .rate:
                UIImage(systemName: "star.fill")
            case .invite:
                UIImage(systemName: "person.2.wave.2.fill")
            case .channel:
                UIImage(systemName: "antenna.radiowaves.left.and.right")
            case .support:
                UIImage(systemName: "lightbulb.fill")
            case .policy:
                UIImage(systemName: "lock.shield.fill")
            case .tos:
                UIImage(systemName: "signature")
            case .license:
                UIImage(systemName: "c.circle")
            case .advanced:
                UIImage(systemName: "ellipsis.circle.fill")
            }
        }
        
        static func row(for destination: SettingsCoordinator.InternalDestination) -> Self? {
            switch destination {
            case .betaFeedback:
                .betaFeedback
            case .developer:
                .developer
            case .privacy:
                .privacy
            case .appearance:
                .appearance
            case .notifications:
                .notifications
            case .chat:
                .chat
            case .media:
                .media
            case .storage:
                .storage
            case .passcode:
                .passcode
            case .calls:
                .calls
            case .desktop:
                .desktop
            case .web:
                .web
            case .invite:
                .invite
            case .channel:
                .channel
            case .support:
                .support
            case .policy:
                .policy
            case .tos:
                .tos
            case .license:
                .license
            case .advanced:
                .advanced
            case .workInfo:
                .workAd
            case .workReferral:
                .workReferral
            }
        }
    }
}
