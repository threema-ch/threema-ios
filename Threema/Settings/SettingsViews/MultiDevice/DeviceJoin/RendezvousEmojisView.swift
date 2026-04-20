import SwiftUI

struct RendezvousEmojisView: View {
    
    let rendezvousHash: Data
    
    @Binding var rendezvousHashConfirmed: Bool
    
    @State private var rendezvousEmojiSets = [RendezvousEmojis.Set]()
    @State var isHidden = false
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(rendezvousEmojiSets) { rendezvousEmojis in
                Button {
                    if rendezvousEmojis.fromRendezvousPathHash {
                        rendezvousHashConfirmed = true
                    }
                    else {
                        Task { @MainActor in
                            withAnimation {
                                isHidden = true
                            }
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            rendezvousEmojiSets = RendezvousEmojis.emojiSets(for: rendezvousHash)
                        }
                    }
                } label: {
                    Label {
                        // No text as this might confuse the accessibility label
                    } icon: {
                        HStack(spacing: 18) {
                            // TODO: (IOS-3892) This might lead to multiple Emojis with the same ID in one view e.g. if the same one is shown multiple times
                            
                            ForEach(rendezvousEmojis.emojis) { emoji in
                                Image(emoji.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .accessibilityLabel(Text(
                                        .init(emoji.localizedString),
                                        tableName: "RendezvousEmoji"
                                    ))
                            }
                        }
                        .padding(4)
                    }
                    .labelStyle(IconOnlyLabelStyle())
                }
                .buttonStyle(BorderedButtonStyle())
            }
        }
        .opacity(isHidden ? 0.0 : 1.0)
        .onAppear {
            rendezvousEmojiSets = RendezvousEmojis.emojiSets(for: rendezvousHash)
        }
        .onChange(of: rendezvousEmojiSets) {
            withAnimation {
                isHidden = false
            }
        }
    }
}

struct RendezvousEmojis_Previews: PreviewProvider {
    static var previews: some View {
        RendezvousEmojisView(
            rendezvousHash: Data([
                0x58, 0x02, 0x88, 0xFA, 0x0E, 0xEE, 0x0A, 0xF1, 0x6A, 0x76, 0xBE, 0x8D,
            ]),
            rendezvousHashConfirmed: .constant(false)
        )
        .padding()
    }
}
