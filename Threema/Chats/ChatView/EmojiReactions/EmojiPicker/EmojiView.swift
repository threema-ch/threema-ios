import SwiftUI
import ThreemaFramework

struct EmojiVariantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.selectEmojiVariant) private var selectEmojiVariant
    
    var emoji: EmojiVariant
    
    var body: some View {
        emojiButton
            .buttonStyle(HighlightedButtonStyle())
    }
    
    private var emojiButton: some View {
        Button {
            selectEmojiVariant?(emoji)
            dismiss()
        } label: {
            VStack {
                Text(emoji.rawValue)
                    .font(.largeTitle)
            }
        }
    }
}

// MARK: - EmojiVariantView.HighlightedButtonStyle

extension EmojiVariantView {
    struct HighlightedButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(configuration.isPressed ? Color.accentColor : Color.clear)
                .clipShape(Circle())
                .scaleEffect(configuration.isPressed ? ChatViewConfiguration.EmojiReactions.Picker.onPressScale : 1.0)
                .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
        }
    }
}
