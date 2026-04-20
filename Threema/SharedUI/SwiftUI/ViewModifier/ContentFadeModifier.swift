import SwiftUI

struct ContentFadeModifier: ViewModifier {
    var leadingColor: Color = .white
    var trailingColor: Color = .clear
    var fadeLength: CGFloat = 5

    func body(content: Content) -> some View {
        content
            .mask {
                HStack {
                    LinearGradient(
                        gradient: Gradient(colors: [leadingColor, trailingColor]),
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                    .frame(width: fadeLength)
                    VStack { }
                    Color.white
                    VStack { }
                    LinearGradient(
                        gradient: Gradient(colors: [leadingColor, trailingColor]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: fadeLength)
                }
                .frame(maxWidth: .infinity)
            }
    }
}

extension View {
    func horizontalFadeOut(
        leadingColor: Color = .white,
        trailingColor: Color = .clear,
        fadeLength: CGFloat = 5
    ) -> some View {
        modifier(ContentFadeModifier(leadingColor: leadingColor, trailingColor: trailingColor, fadeLength: fadeLength))
    }
}
