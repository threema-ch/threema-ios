import SwiftUI
import ThreemaMacros

struct LoadingView: View {
    
    @State var viewModel: LoadingViewModel
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                stateContent
                
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - State Content
    
    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.state {
        case .initializing:
            loadingContent(message: nil)
            
        case let .loading(message):
            loadingContent(message: message)
            
        case let .error(error):
            errorContent(error: error)
            
        case .locked:
            lockedContent()
        }
    }
    
    // MARK: - Loading Content
    
    @ViewBuilder
    private func loadingContent(message: String?) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.primary)
                .scaleEffect(1.3)
            
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.foreground.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(minHeight: 80)
    }
    
    // MARK: - Error Content
    
    @ViewBuilder
    private func errorContent(error: LoadingViewModel.Error) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            
            textSection(title: error.title, message: error.message)
            
            Spacer()
            
            if let onRetry = error.onRetry {
                ThreemaButton(
                    title: viewModel.retryButtonTitle,
                    style: .borderedProminent,
                    size: .fullWidth
                ) {
                    onRetry()
                }
            }
            
            if let onRemove = error.onRemove {
                ThreemaButton(
                    title: viewModel.removeButtonTitle,
                    role: .destructive,
                    style: .bordered,
                    size: .fullWidth
                ) {
                    viewModel.showRemoveConfirmation = true
                }
                .confirmationDialog(
                    viewModel.removeConfirmationTitle,
                    isPresented: $viewModel.showRemoveConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(viewModel.removeConfirmationRemoveButtonTitle, role: .destructive, action: onRemove)
                    
                    Button(viewModel.removeConfirmationCancelButtonTitle, role: .cancel) {
                        // no-op
                    }
                }
            }
        }
        .frame(minHeight: 80)
    }
    
    // MARK: - Locked Content
    
    @ViewBuilder
    private func lockedContent() -> some View {
        textSection(
            title: #localize("rs_view_locked_title"),
            message: #localize("rs_view_locked_description")
        )
    }
    
    // MARK: - Text section
    
    @ViewBuilder
    private func textSection(title: String?, message: String) -> some View {
        VStack {
            if let title {
                Text(title)
                    .font(.title)
                    .bold()
                    .padding(.bottom, 2)
            }
            Text(message)
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Previews

#Preview("Initializing") {
    LoadingView(viewModel: {
        let viewModel = LoadingViewModel()
        viewModel.setInitializing()
        return viewModel
    }())
}

#Preview("Loading") {
    LoadingView(viewModel: {
        let viewModel = LoadingViewModel()
        viewModel.setLoading()
        return viewModel
    }())
}

#Preview("Loading with Message") {
    LoadingView(viewModel: {
        let viewModel = LoadingViewModel()
        viewModel.setLoading(message: "Initializing database…")
        return viewModel
    }())
}

#Preview("Error - Retryable") {
    LoadingView(
        viewModel: {
            let viewModel = LoadingViewModel()
            viewModel.setError(
                message: "Failed to connect to server. Please check your internet connection.",
                onRetry: {
                    // no-op
                }
            )
            return viewModel
        }()
    )
}

#Preview("Error - Not Retryable") {
    LoadingView(
        viewModel: {
            let viewModel = LoadingViewModel()
            viewModel.setError(
                message: "Database migration failed. Please reinstall the app.",
            )
            return viewModel
        }()
    )
}

#Preview("Error - Retryable and Removable") {
    LoadingView(
        viewModel: {
            let viewModel = LoadingViewModel()
            viewModel.setError(
                message: "Failed to connect to server. Please check your internet connection.",
                onRetry: {
                    // no-op
                },
                onRemove: {
                    // no-op
                }
            )
            return viewModel
        }()
    )
}

#Preview("Error - Retryable, Removable and Title") {
    LoadingView(
        viewModel: {
            let viewModel = LoadingViewModel()
            viewModel.setError(
                title: "Failed to Connect to Server",
                message: "Please check your internet connection",
                onRetry: {
                    // no-op
                },
                onRemove: {
                    // no-op
                }
            )
            return viewModel
        }()
    )
}

#Preview("Locked") {
    LoadingView(viewModel: {
        let viewModel = LoadingViewModel()
        viewModel.setLocked()
        return viewModel
    }())
}
