#if DEBUG
    import SwiftUI

    /// Renders preview content in its *pushed* state inside a `NavigationStack`.
    ///
    /// A stack's root screen has no back button, so previewing a screen with `NavigationStack { ... }`
    /// never shows the navigation bar it has in the real flow. This wrapper starts the stack with an
    /// empty placeholder root and immediately pushes `content` on top of it, so the back button (which
    /// pops back to the placeholder) is present and functional.
    ///
    /// ```swift
    /// #Preview {
    ///     PushedPreview(rootTitle: "Recovery Key") {
    ///         MyScreen()
    ///     }
    /// }
    /// ```
    struct PushedPreview<Content: View>: View {
        private let rootTitle: String
        private let rootTitleDisplayMode: NavigationBarItem.TitleDisplayMode
        private let content: Content

        /// A non-empty path pushes `content` on top of the placeholder root right away.
        @State private var path = [0]

        /// - Parameters:
        ///   - rootTitle: Title of the placeholder root; also the pushed screen's back-button label.
        ///   - rootTitleDisplayMode: Title display mode of the placeholder root.
        ///   - content: The screen to render pushed.
        init(
            rootTitle: String = "",
            rootTitleDisplayMode: NavigationBarItem.TitleDisplayMode = .inline,
            @ViewBuilder content: () -> Content
        ) {
            self.rootTitle = rootTitle
            self.rootTitleDisplayMode = rootTitleDisplayMode
            self.content = content()
        }

        var body: some View {
            NavigationStack(path: $path) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .navigationTitle(rootTitle)
                    .navigationBarTitleDisplayMode(rootTitleDisplayMode)
                    .navigationDestination(for: Int.self) { _ in
                        content
                    }
            }
            .transaction { transaction in
                // Disable the push animation so screenshots don't catch the destination mid-slide.
                transaction.disablesAnimations = true
            }
        }
    }
#endif
