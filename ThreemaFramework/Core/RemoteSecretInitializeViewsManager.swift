import CocoaLumberjackSwift
import Keychain
import RemoteSecret
import RemoteSecretProtocol
import SwiftUI
import ThreemaEssentials

public final class RemoteSecretInitializeViewsManager: ObservableObject {
    
    enum Error: Swift.Error {
        case failedToStart
    }
    
    private enum ViewState: Equatable, Sendable {
        case fetching
        case timeoutError
        case generalError
        case blocked
        case mismatch
    }
    
    private let navigationController: UINavigationController?

    private var currentState: ViewState?
    private var retries = 0
    private var showDeleteAfterRetries: Int
    private var isInitialFetch = true
    
    /// Stream to handle state updates
    private let (viewStateStream, viewStateContinuation) = {
        let (stream, continuation) = AsyncStream.makeStream(of: ViewState.self)
        
        // Set initial state
        continuation.yield(.fetching)
        
        return (stream, continuation)
    }()
    
    // MARK: - Lifecycle
    
    public init(
        navigationController: UINavigationController?,
        showDeleteAfterRetries: Int = 5
    ) {
        self.navigationController = navigationController
        self.showDeleteAfterRetries = showDeleteAfterRetries
    }
    
    // MARK: - Public method
    
    @MainActor public func start(
        identity: ThreemaIdentity? = nil,
        onDelete: (() -> Void)?,
        onCancel: (() -> Void)?
    ) async throws -> RemoteSecretManagerProtocol {
        
        let remoteSecretManagerCreator = RemoteSecretManagerCreator(
            appInfo: ThreemaUtility.appInfo,
            httpClient: HTTPClient(),
            keychainManagerType: KeychainManager.self
        )
        
        // Our code needs to ensure that we only close the viewStateStream when a remote secret manager exists. We can't
        // rely on the complier as he cannot ensure the the stream doesn't end before we assign this value once
        var remoteSecretManager: RemoteSecretManagerProtocol!
        
        // We loop over all the states as long as we're unable to successfully initialize remote secret
        for await newState in viewStateStream {
            
            // We are only interested in state changes
            guard newState != currentState else {
                continue
            }
            
            // Update `currentState`
            currentState = newState
            
            // Handle change
            switch newState {
            case .fetching:

                var fetchingFinished = false

                // Show fetch view, we dispatch the first showing for a bit, to not disturb non remote secret users
                // with a fetching screen
                Task {
                    if isInitialFetch {
                        try await Task.sleep(seconds: 0.2)
                        isInitialFetch = false
                    }
                    
                    guard !fetchingFinished, currentState == .fetching else {
                        return
                    }

                    show(RemoteSecretFetchView())
                }
                
                // Start and handle fetch
                do {
                    remoteSecretManager = try await remoteSecretManagerCreator.initialize(identity: identity) {
                        do {
                            return try await ServerInfoProviderFactory.makeServerInfoProvider().workServerURL()
                        }
                        catch {
                            DDLogError("Failed to get work server url: \(error)")
                            return nil
                        }
                    }

                    viewStateContinuation.onTermination = { termination in
                        switch termination {
                        case .cancelled:
                            break
                        case .finished:
                            Task { @MainActor in
                                fetchingFinished = true
                            }
                        @unknown default:
                            DDLogError("Unknown termination state")
                            assertionFailure()
                        }
                    }

                    // `break` doesn't work here. This completes the loop
                    viewStateContinuation.finish()
                }
                catch RemoteSecretManagerError.blocked {
                    try advance(to: .blocked)
                }
                catch RemoteSecretManagerError.timeout {
                    try advance(to: .timeoutError)
                }
                catch RemoteSecretManagerError.mismatch {
                    try advance(to: .mismatch)
                }
                catch {
                    try advance(to: .generalError)
                }
                
            case .timeoutError:
                showBlockView(type: .timeout, onDelete: onDelete, onCancel: onCancel)

            case .generalError:
                showBlockView(type: .generalError, onDelete: onDelete, onCancel: onCancel)
                
            case .blocked:
                showBlockView(type: .blocked, onDelete: onDelete, onCancel: onCancel)
           
            case .mismatch:
                showBlockView(type: .mismatch, onDelete: onDelete, onCancel: onCancel)
            }
        }
        
        assert(remoteSecretManager != nil, "remoteSecretManager should never be nil")
        
        return remoteSecretManager
    }
    
    // MARK: - Private helper
    
    private func showBlockView(
        type: RemoteSecretBlockViewModel.ViewType,
        onDelete: (() -> Void)?,
        onCancel: (() -> Void)?
    ) {
        let viewModel = RemoteSecretBlockViewModel(
            type: type,
            onRetry: { [weak self] in
                try? self?.advance(to: .fetching)
            },
            onDelete: retries < showDeleteAfterRetries ? nil : onDelete,
            onCancel: onCancel
        )
        
        show(RemoteSecretBlockView(viewModel: viewModel))
    }
    
    private func show(_ view: some View) {
        let vc = UIHostingController(rootView: view)
        navigationController?.viewControllers = [vc]
    }
        
    private func advance(to nextViewState: ViewState) throws {
        
        guard navigationController != nil else {
            throw Error.failedToStart
        }
        
        // If we advance to get fetching, we increase retries
        if nextViewState == .fetching {
            retries += 1
        }
        
        viewStateContinuation.yield(nextViewState)
    }
}
