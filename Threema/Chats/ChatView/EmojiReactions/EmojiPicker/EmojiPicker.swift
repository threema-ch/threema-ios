import SwiftUI
import ThreemaFramework

/// A view component that renders an emoji picker interface.
public struct EmojiPicker: View {
    @StateObject var model: ReactionModel
    @State var toolbarVisible = true
    
    public var body: some View {
        ItemList(toolbarVisible: $toolbarVisible)
            .emojiToolbar(isVisible: $toolbarVisible)
            .skinTonePicker()
            .registerSizeObserver()
            .environment(\.isSearchActive, !toolbarVisible)
            .environment(
                \.reactionEntries,
                model
                    .reactionEntries
                    .filter { $0.displayValue != "�" }
                    .sorted(by: { $0.userReactionEntries.count > $1.userReactionEntries.count })
                    .sorted(by: {
                        if let d1 = $0.userReactionEntries.map(\.sortDate).sorted().first,
                           let d2 = $1.userReactionEntries.map(\.sortDate).sorted().first {
                            d1 > d2
                        }
                        else {
                            false
                        }
                    })
            )
    }
}
