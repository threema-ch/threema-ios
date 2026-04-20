import SwiftUI

struct MapControlButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .padding(12)
                .foregroundColor(.accentColor)
        }
        .buttonStyle(MapControlButtonStyle())
        .modifier(MapControlButtonContainer())
    }
}

struct MapControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.2 : 1.0)
    }
}
