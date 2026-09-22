#if DEBUG
    import SwiftUI

    protocol PreviewCase: CaseIterable, Sendable where AllCases: Sendable {
        associatedtype Content: View

        /// Name of the state, shown in the preview canvas and used for the screenshot file name.
        var title: String { get }

        /// The screen in this state, wrapped in whatever preview scaffolding it needs.
        @MainActor @ViewBuilder var view: Content { get }
    }
#endif
