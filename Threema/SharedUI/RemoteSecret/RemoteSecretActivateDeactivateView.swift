import SwiftUI
import ThreemaFramework

struct RemoteSecretActivateDeactivateView: View {
    @StateObject var viewModel: RemoteSecretActivateDeactivateViewModel
    @Environment(\.dismiss) var dismiss

    @State private var navigate = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text(viewModel.type.title)
                    .font(.title)
                    .bold()
                    .padding()
                
                GroupBox {
                    Text(viewModel.type.boxText)
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom)
                
                Spacer()
                
                ThreemaButton(
                    title: viewModel.createBackupButtonTitle,
                    style: .borderedProminent,
                    size: .fullWidth
                ) {
                    dismiss()
                    NotificationCenter.default.post(name: Notification.Name(kNotificationShowProfile), object: nil)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                NavigationLink(
                    destination: DarkModeUIViewControllerRepresentable(
                        rootView: DeleteRevokeView {
                            dismiss()
                        }
                    ),
                    isActive: $navigate
                ) {
                    EmptyView()
                }
                .accessibilityHidden(true)
      
                ThreemaButton(
                    title: viewModel.removeButtonTitle,
                    role: .destructive,
                    style: .bordered,
                    size: .fullWidth
                ) {
                    navigate.toggle()
                }
                
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                Button {
                    dismiss()
                } label: {
                    Text(viewModel.notNowButtonTitle)
                        .font(.title3)
                        .bold()
                }
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .ignoresSafeArea(.all, edges: [.horizontal])
        }
    }
}

#Preview {
    RemoteSecretActivateDeactivateView(viewModel: RemoteSecretActivateDeactivateViewModel(type: .activate))
}
