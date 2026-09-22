import Foundation
import Observation
import ThreemaMacros

@Observable
@MainActor
final class LoadingViewModel {
    
    // MARK: - State
    
    private(set) var state: State = .initializing
    
    // MARK: - State Enum
    
    enum State: Equatable {
        /// Initial state before any checks
        case initializing
        
        /// Loading with optional progress message
        case loading(message: String?)
        
        /// Error occurred, may allow retry
        case error(Error)
        
        /// App access is locked
        case locked
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.initializing, .initializing):
                true
            case let (.loading(lhsMsg), .loading(rhsMsg)):
                lhsMsg == rhsMsg
            case let (.error(lhsErr), .error(rhsErr)):
                lhsErr == rhsErr
            default:
                false
            }
        }
    }
    
    // MARK: - Localized Strings
    
    @ObservationIgnored lazy var retryButtonTitle = #localize("retry")
    
    @ObservationIgnored lazy var removeButtonTitle: String = #localize("my_profile_delete_info_button")
    
    @ObservationIgnored lazy var removeConfirmationTitle = String.localizedStringWithFormat(
        #localize("loading_view_remove_confirmation_title"),
        TargetManager.localizedAppName
    )
    @ObservationIgnored lazy var removeConfirmationRemoveButtonTitle = #localize("my_profile_delete_info_button")
    @ObservationIgnored lazy var removeConfirmationCancelButtonTitle = #localize("cancel")
    
    // MARK: - Confirmation state
    
    var showRemoveConfirmation = false
    
    // MARK: - Error
    
    struct Error: Swift.Error, Equatable {
        let title: String?
        let message: String
        let onRetry: (@Sendable () -> Void)?
        let onRemove: (@Sendable () -> Void)?
        
        static func == (lhs: Error, rhs: Error) -> Bool {
            lhs.title == rhs.title &&
                lhs.message == rhs.message &&
                ((lhs.onRetry == nil && rhs.onRetry == nil) || (lhs.onRetry != nil && rhs.onRetry != nil)) &&
                ((lhs.onRemove == nil && rhs.onRemove == nil) || (lhs.onRemove != nil && rhs.onRemove != nil))
        }
    }
    
    // MARK: - State Updates
    
    func setInitializing() {
        state = .initializing
    }
    
    func setLoading(message: String? = nil) {
        state = .loading(message: message)
    }
    
    func setError(
        title: String? = nil,
        message: String,
        onRetry: (@Sendable () -> Void)? = nil,
        onRemove: (@Sendable () -> Void)? = nil
    ) {
        state = .error(Error(title: title, message: message, onRetry: onRetry, onRemove: onRemove))
    }
    
    func setLocked() {
        state = .locked
    }
}

// MARK: - Convenience Properties

extension LoadingViewModel {
    
    var isLoading: Bool {
        switch state {
        case .initializing, .loading:
            true
        case .error, .locked:
            false
        }
    }
    
    var loadingMessage: String? {
        switch state {
        case let .loading(message):
            message
        default:
            nil
        }
    }
    
    var error: Error? {
        switch state {
        case let .error(error):
            error
        default:
            nil
        }
    }
}
