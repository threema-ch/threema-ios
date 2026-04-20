import SwiftUI

struct RemoteSecretFetchView: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("rs_view_fetching")
                .font(.headline)
                .padding()
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

#Preview {
    RemoteSecretFetchView()
}
