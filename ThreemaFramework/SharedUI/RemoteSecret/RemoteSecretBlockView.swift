import SwiftUI

struct RemoteSecretBlockView: View {
    @StateObject var viewModel: RemoteSecretBlockViewModel

    var body: some View {
        VStack {
            Spacer()
         
            Text(viewModel.type.title)
                .font(.title)
                .bold()
                .padding(.bottom, 2)
            Text(viewModel.type.description)
            
            Spacer()
            
            // Retry button
            if viewModel.showRetryButton {
                ThreemaButton(
                    title: viewModel.retryButtonTitle,
                    style: .borderedProminent,
                    size: .fullWidth
                ) {
                    viewModel.retryButtonTapped()
                }
                .padding(.bottom, (viewModel.showDeleteButton || viewModel.showCancelButton) ? 8 : 0)
            }
            
            // Delete button
            if viewModel.showDeleteButton {
                ThreemaButton(
                    title: viewModel.deleteButtonTitle,
                    role: .destructive,
                    style: .borderless,
                    size: .small
                ) {
                    viewModel.deleteButtonTapped()
                }

                .padding(.bottom, (viewModel.showCancelButton || viewModel.showCancelButton) ? 8 : 0)
                .confirmationDialog(
                    viewModel.alertTitle,
                    isPresented: $viewModel.showDeleteAlert,
                    titleVisibility: .visible,
                    actions: {
                        Button(
                            viewModel.alertConfirmButtonTitle,
                            role: .destructive
                        ) {
                            viewModel.delete()
                        }
                        
                        Button(viewModel.alertCancelButtonTitle, role: .cancel) {
                            // Do nothing
                        }
                    }
                )
            }
            
            // Cancel button
            if viewModel.showCancelButton {
                ThreemaButton(
                    title: viewModel.cancelButtonTitle,
                    role: .destructive,
                    style: .borderless,
                    size: .small
                ) {
                    viewModel.cancelButtonTapped()
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .ignoresSafeArea(.all, edges: [.top, .horizontal])
    }
}

#Preview {
    RemoteSecretBlockView(viewModel: RemoteSecretBlockViewModel(
        type: .generalError,
        onRetry: nil,
        onDelete: nil,
        onCancel: nil
    ))
}
