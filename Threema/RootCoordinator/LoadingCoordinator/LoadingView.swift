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
            .padding(.horizontal, 16)
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            
            Text(error.message)
                .font(.body)
                .foregroundStyle(.foreground.opacity(0.85))
                .multilineTextAlignment(.center)
            
            if error.isRetryable {
                Button(action: {
                    viewModel.retry()
                }, label: {
                    Text(#localize("retry"))
                        .font(.headline)
                        .foregroundStyle(Color(.systemBackground))
                        .frame(minWidth: 140)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 28)
                        .background(
                            Color.accentColor,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                })
                .buttonStyle(AdaptiveButtonStyle())
            }
        }
        .frame(minHeight: 80)
    }
}

private struct AdaptiveButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            Button(configuration)
                .buttonStyle(.glassProminent)
        }
        else {
            Button(configuration)
                .buttonStyle(.plain)
        }
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
                isRetryable: true
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
                isRetryable: false
            )
            return viewModel
        }()
    )
}
