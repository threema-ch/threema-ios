import Foundation
import Observation

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
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.initializing, .initializing):
                true
            case let (.loading(lhsMsg), .loading(rhsMsg)):
                lhsMsg == rhsMsg
            case let (.error(lhsErr), .error(rhsErr)):
                lhsErr.localizedDescription == rhsErr.localizedDescription
            default:
                false
            }
        }
    }
    
    // MARK: - Error
    
    struct Error: Swift.Error, Equatable {
        let message: String
        let isRetryable: Bool
        
        static func == (lhs: Error, rhs: Error) -> Bool {
            lhs.message == rhs.message && lhs.isRetryable == rhs.isRetryable
        }
    }
    
    // MARK: - Callbacks
    
    var onRetry: (() -> Void)?
    
    // MARK: - State Updates
    
    func setInitializing() {
        state = .initializing
    }
    
    func setLoading(message: String? = nil) {
        state = .loading(message: message)
    }
    
    func setError(message: String, isRetryable: Bool = true) {
        state = .error(Error(message: message, isRetryable: isRetryable))
    }
    
    func retry() {
        onRetry?()
    }
}

// MARK: - Convenience Properties

extension LoadingViewModel {
    
    var isLoading: Bool {
        switch state {
        case .initializing, .loading:
            true
        case .error:
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
