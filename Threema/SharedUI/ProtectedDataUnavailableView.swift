import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct ProtectedDataUnavailableView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Text(#localize("protectedDataUnavailable_error_text"))
                .font(.headline)
                .padding(.horizontal)
            
            Spacer()
            
            ThreemaButton(
                title: #localize("protectedDataUnavailable_exitbutton"),
                style: .borderedProminent,
                size: .fullWidth
            ) {
                exit(0)
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .ignoresSafeArea(.all, edges: [.top, .horizontal])
    }
}

#Preview {
    ProtectedDataUnavailableView()
}
