import Foundation
import Keychain
import ThreemaMacros

final class RemoteSecretBlockViewModel: ObservableObject {
    
    // MARK: - Types
    
    enum ViewType {
        case generalError
        case timeout
        case blocked
        case mismatch
        
        var title: String {
            switch self {
            case .generalError:
                #localize("rs_view_failed_title")
            case .timeout:
                #localize("rs_view_disconnected_title")
            case .blocked:
                #localize("rs_view_locked_title")
            case .mismatch:
                #localize("rs_view_mismatch_title")
            }
        }
        
        var description: String {
            switch self {
            case .generalError:
                #localize("rs_view_failed_description")
            case .timeout:
                #localize("rs_view_disconnected_description")
            case .blocked:
                #localize("rs_view_locked_description")
            case .mismatch:
                #localize("rs_view_mismatch_description")
            }
        }
    }
    
    // MARK: - Strings

    lazy var alertTitle = String.localizedStringWithFormat(
        #localize("my_profile_delete_info_alert_title"),
        TargetManager.localizedAppName
    )
    lazy var alertConfirmButtonTitle = #localize("my_profile_delete_info_alert_confirm")
    lazy var alertCancelButtonTitle = #localize("cancel")

    lazy var retryButtonTitle: String =
        switch type {
        case .generalError, .mismatch:
            #localize("rs_view_failed_button_title")
        case .timeout:
            #localize("rs_view_disconnected_button_title")
        case .blocked:
            ""
        }
    
    lazy var deleteButtonTitle: String = #localize("rs_view_blocked_button_title")
    lazy var cancelButtonTitle: String = #localize("cancel")
    
    // MARK: - Published properties

    @Published var type: ViewType
    @Published var showDeleteAlert = false
    
    // MARK: - Properties
    
    var showRetryButton: Bool {
        onRetry != nil && (type == .timeout || type == .generalError || type == .mismatch)
    }
    
    var showDeleteButton: Bool {
        onDelete != nil
    }
    
    var showCancelButton: Bool {
        onCancel != nil
    }
    
    private let onRetry: (() -> Void)?
    private let onDelete: (() -> Void)?
    private let onCancel: (() -> Void)?

    // MARK: - Lifecycle
    
    init(type: ViewType, onRetry: (() -> Void)?, onDelete: (() -> Void)?, onCancel: (() -> Void)?) {
        self.type = type
        self.onRetry = onRetry
        self.onDelete = onDelete
        self.onCancel = onCancel
    }
    
    // MARK: - Public functions

    func retryButtonTapped() {
        onRetry?()
    }
    
    func deleteButtonTapped() {
        showDeleteAlert = true
    }
    
    func delete() {
        onDelete?()
    }
    
    func cancelButtonTapped() {
        onCancel?()
    }
}
