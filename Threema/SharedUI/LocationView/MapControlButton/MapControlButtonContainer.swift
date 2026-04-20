import SwiftUI

struct MapControlButtonContainer: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
            content
        }
        .contentShape(Rectangle())
        .frame(width: 44, height: 44)
    }
}
