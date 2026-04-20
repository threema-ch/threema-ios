import CocoaLumberjackSwift
import Foundation
import ThreemaFramework
import ThreemaMacros

@MainActor
final class ErrorNotificationHandler: NSObject {
    @objc static let shared = ErrorNotificationHandler()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private

    @objc override private init() {
        super.init()

        NotificationCenter.default.addObserver(forName: .serverMessage, object: nil, queue: .main) { notification in
            MainActor.assumeIsolated {
                guard let owner = AppDelegate.shared().currentTopViewController() else {
                    DDLogError("Unable to show alert for 'serverMessage' notification")
                    return
                }
                
                let title = #localize("server_message_title")
                let message = notification.userInfo?[kKeyMessage] as? String ?? ""
                UIAlertTemplate.showAlert(
                    owner: owner,
                    title: title,
                    message: message,
                    actionOk: nil
                )
            }
        }

        NotificationCenter.default
            .addObserver(forName: .errorConnectionFailed, object: nil, queue: .main) { notification in
                MainActor.assumeIsolated {
                    guard let owner = AppDelegate.shared().currentTopViewController() else {
                        DDLogError("Unable to show alert for 'errorConnectionFailed' notification")
                        return
                    }
                    
                    let title = notification.userInfo?[kKeyTitle] as? String ?? "Connection error"
                    let message = notification.userInfo?[kKeyMessage] as? String ?? ""
                    UIAlertTemplate.showAlert(
                        owner: owner,
                        title: title,
                        message: message,
                        actionOk: nil
                    )
                }
            }

        NotificationCenter.default.addObserver(forName: .errorPublicKeyMismatch, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                guard let owner = AppDelegate.shared().currentTopViewController() else {
                    DDLogError("Unable to show alert for 'errorPublicKeyMismatch' notification")
                    return
                }
                
                let title = #localize("public_key_mismatch_title")
                let message = #localize("public_key_mismatch_message")
                UIAlertTemplate.showAlert(
                    owner: owner,
                    title: title,
                    message: message,
                    actionOk: nil
                )
            }
        }

        NotificationCenter.default.addObserver(forName: .errorRogueDevice, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                guard let owner = AppDelegate.shared().currentTopViewController() else {
                    DDLogError("Unable to show alert for 'errorRogueDevice' notification")
                    return
                }
                
                let title = #localize("error_rogue_device_title")
                let message = String.localizedStringWithFormat(
                    #localize("error_rogue_device_message"),
                    TargetManager.localizedAppName,
                    TargetManager.localizedAppName
                )
                let titleOk = #localize("ok")
                let actionOk: ((UIAlertAction) -> Void) = { _ in
                    ServerConnector.shared().clearDeviceCookieChangedIndicator()
                }
                let titleCancel = #localize("error_rogue_device_more_info_button")
                let actionCancel: ((UIAlertAction) -> Void) = { _ in
                    ServerConnector.shared().clearDeviceCookieChangedIndicator()
                    UIApplication.shared.open(ThreemaURLProvider.rogueDeviceInfo)
                }
                UIAlertTemplate.showAlert(
                    owner: owner,
                    title: title,
                    message: message,
                    titleOk: titleOk,
                    actionOk: actionOk,
                    titleCancel: titleCancel,
                    actionCancel: actionCancel
                )
            }
        }
    }
}
