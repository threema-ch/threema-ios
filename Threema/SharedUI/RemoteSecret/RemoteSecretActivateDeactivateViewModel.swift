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
