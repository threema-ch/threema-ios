import SwiftUI

struct ThreemaLogoView: View {
    var body: some View {
        VStack {
            Image(Colors.callKitLogoResource)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}
