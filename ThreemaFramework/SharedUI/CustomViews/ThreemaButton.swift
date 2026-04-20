import SwiftUI

// MARK: - Type

public enum ThreemaButtonSize {
    case fullWidth
    case small
}

public struct ThreemaButton<Style: PrimitiveButtonStyle>: View {

    // MARK: - Properties

    @Environment(\.isEnabled) private var isEnabled

    let title: String
    let action: () -> Void
    let size: ThreemaButtonSize
    let style: Style
    let role: ButtonRole?
    
    // MARK: - Subviews
    
    var label: some View {
        Text(title)
            .font(size == .fullWidth ? .title3.weight(.semibold) : .headline)
            .apply { text in
                if !isEnabled {
                    text
                        .foregroundColor(.secondary)
                }
                else if style is BorderedProminentButtonStyle {
                    text
                        .foregroundColor(Colors.textProminentButton.color)
                }
                else {
                    text
                }
            }
            .multilineTextAlignment(.center)
            .apply { text in
                if size == .fullWidth {
                    text
                        .frame(maxWidth: 400)
                        .padding(10)
                }
                else {
                    text
                        .padding(10)
                }
            }
    }
    
    // MARK: - Lifecycle

    public init(
        title: String,
        role: ButtonRole? = nil,
        style: Style,
        size: ThreemaButtonSize,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.role = role
        self.size = size
        self.style = style
        self.action = action
    }
    
    // MARK: - Body

    public var body: some View {
        if let role {
            Button(role: role) {
                action()
            } label: {
                label
            }
            .threemaButton(style: style, size: size)
        }
        else {
            Button {
                action()
            } label: {
                label
            }
            .threemaButton(style: style, size: size)
        }
    }
}
    
private struct ThreemaButtonModifier<Style: PrimitiveButtonStyle>: ViewModifier {
    
    private var buttonStyle: Style
    private var buttonSize: ThreemaButtonSize
    
    fileprivate init(buttonStyle: Style, buttonSize: ThreemaButtonSize) {
        self.buttonStyle = buttonStyle
        self.buttonSize = buttonSize
    }
    
    fileprivate func body(content: Content) -> some View {
        content
            .buttonStyle(buttonStyle)
            .apply { button in
                if #available(iOS 26.0, *) {
                    if !(buttonStyle is PlainButtonStyle), !(buttonStyle is BorderlessButtonStyle) {
                        button
                            .glassEffect(.regular.interactive())
                    }
                    else {
                        button
                    }
                }
                else {
                    if buttonSize == .small {
                        button
                            .clipShape(Capsule())
                    }
                    else {
                        button
                            .cornerRadius(12)
                    }
                }
            }
    }
}

extension View {
    fileprivate func threemaButton(style: some PrimitiveButtonStyle, size: ThreemaButtonSize) -> some View {
        modifier(ThreemaButtonModifier(buttonStyle: style, buttonSize: size))
    }
}

#Preview {
    VStack {
        ThreemaButton(title: "Full Size Button", style: .bordered, size: .fullWidth) { }
        ThreemaButton(title: "Small", style: .bordered, size: .small) { }
    }
    .padding()
}
