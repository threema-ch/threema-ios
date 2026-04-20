import SwiftUI

struct DeviceJoinProgressView: View {
    
    let text: String
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(text)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

struct DeviceJoinProgressView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceJoinProgressView(text: "Connecting...")
    }
}
