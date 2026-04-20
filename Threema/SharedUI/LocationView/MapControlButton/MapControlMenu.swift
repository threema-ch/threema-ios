import SwiftUI

struct MapControlMenu<Content: View>: View {
    let systemImage: String
    @ViewBuilder let menuItems: () -> Content

    var body: some View {
        Menu {
            menuItems()
        } label: {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .padding(12)
                .foregroundColor(.accentColor)
        }
        .modifier(MapControlButtonContainer())
    }
}
