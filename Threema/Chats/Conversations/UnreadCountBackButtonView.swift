import SwiftUI

/// Unread count to be shown in back buttons for iOS 26+
///
/// This attempts to match size and shape of unread counts in back buttons on iOS 26.1
///
/// See `ConversationListViewController` for an example usage
struct UnreadCountBackButtonView: View {
    
    /// Unread count to show
    let count: Int
    
    var body: some View {
        Text(verbatim: String(count))
            .monospacedDigit() // Prevents different widths for each number
            // As unread back buttons also keep a constant size we do the same
            .font(.system(size: 12, weight: .semibold))
            .kerning(-1)
            .padding(.leading, 5.5)
            .padding(.trailing, 6.4)
            .padding(.vertical, 2)
            .blendMode(.destinationOut)
            .background(Capsule(style: .circular))
            .compositingGroup()
    }
}

#Preview {
    ZStack {
        Color.red
        
        Circle()
            .fill(.green)
            .frame(width: 19.5)
        
        UnreadCountBackButtonView(count: 8)
    }
    .ignoresSafeArea()
}
