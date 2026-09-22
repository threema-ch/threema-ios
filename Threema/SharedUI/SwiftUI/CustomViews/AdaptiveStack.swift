import SwiftUI

/// Arranges its content horizontally, switching to a vertical layout when a compact width is combined with large
/// Dynamic Type sizes.
///
/// Both arrangements are applied through `AnyLayout`, so switching between them preserves the identity of the
/// content: its state survives the transition and the change can be animated.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder let content: Content

    var body: some View {
        layout {
            content
        }
    }

    private var layout: AnyLayout {
        needsVerticalLayout
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout())
    }

    private var needsVerticalLayout: Bool {
        horizontalSizeClass == .compact && dynamicTypeSize > .xxLarge
    }
}

#if DEBUG
    #Preview("Both layouts") {
        VStack(spacing: 24) {
            AdaptiveStack {
                Image(systemName: "externaldrive")
                Text("Horizontal layout")
            }

            AdaptiveStack {
                Image(systemName: "externaldrive")
                Text("Vertical layout")
            }
            .environment(\.dynamicTypeSize, .accessibility3)
        }
    }

    /// Toggling the Dynamic Type size should animate between the two arrangements instead of cutting between them,
    /// which is what verifies the content keeps its identity across the switch.
    #Preview("Transition") {
        struct PreviewContainer: View {
            @State private var usesLargeText = false

            var body: some View {
                VStack(spacing: 32) {
                    AdaptiveStack {
                        Text("Recovery Key")
                        Spacer(minLength: 0)
                        Text(verbatim: "8KP2…N9CQ")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                    .environment(\.horizontalSizeClass, .compact)
                    .environment(\.dynamicTypeSize, usesLargeText ? .accessibility3 : .large)
                    .animation(.default, value: usesLargeText)

                    Button("Toggle Dynamic Type") {
                        usesLargeText.toggle()
                    }
                }
                .padding()
            }
        }

        return PreviewContainer()
    }
#endif
