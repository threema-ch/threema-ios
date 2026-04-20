import Foundation
import ThreemaMacros

/// This class provides the list of available shortcut items.
///
/// To add a new shortcut item, add a new case to the `ActionType` enum.
/// Then add the new case to the `items(for:)` method.
///
@objc final class UIApplicationShortcutItemProvider: NSObject {
    
    enum ActionType {
        case newMessage
        case myID
        case scanQrCode
        
        var localizedTitle: String {
            switch self {
            case .newMessage:
                #localize("application_shortcut_item_new_message")
            case .myID:
                #localize("application_shortcut_item_my_id")
            case .scanQrCode:
                #localize("application_shortcut_item_scan_qr_code")
            }
        }
      
        var icon: String {
            switch self {
            case .newMessage:
                "square.and.pencil"
            case .myID:
                "person.crop.rectangle.fill"
            case .scanQrCode:
                "qrcode.viewfinder"
            }
        }
        
        var type: String {
            switch self {
            case .newMessage:
                "ch.threema.newmessage"
            case .myID:
                "ch.threema.myid"
            case .scanQrCode:
                "ch.threema.scanid"
            }
        }
        
        var item: UIApplicationShortcutItem {
            .init(
                type: type,
                localizedTitle: localizedTitle,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: icon)
            )
        }
    }
    
    /// This method will return an array of shortcut items that are displayed on the home screen.
    ///
    /// - Parameter mdm: used for dynamic shortcut items
    /// - Returns: an array of shortcut items
    @objc static func items(for mdm: MDMSetup) -> [UIApplicationShortcutItem] {
        var items: [ActionType] = [.newMessage, .myID]

        if !mdm.disableAddContact() {
            items.append(.scanQrCode)
        }
        
        return items.map(\.item)
    }
}
