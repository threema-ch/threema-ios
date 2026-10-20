#if DEBUG
    import Observation
    import SwiftUI

    struct ContentSizedSheetPreview<Sheet: View, Background: View>: View {
        private let sheet: Sheet
        private let background: Background

        @State private var sizing: SheetPreviewSizing
        @State private var isPresented = true

        @MainActor
        init(
            @ViewBuilder sheet: (SheetPreviewSizing) -> Sheet,
            @ViewBuilder over background: () -> Background
        ) {
            let sizing = SheetPreviewSizing()

            self.sheet = sheet(sizing)
            self.background = background()
            _sizing = State(initialValue: sizing)
        }

        var body: some View {
            background
                .sheet(isPresented: $isPresented) {
                    sheet
                        .presentationDetents([sizing.detent])
                        .presentationDragIndicator(.visible)
                }
                .transaction { transaction in
                    transaction.disablesAnimations = true
                }
        }
    }

    extension ContentSizedSheetPreview where Background == PreviewBackground {
        @MainActor
        init(@ViewBuilder sheet: (SheetPreviewSizing) -> Sheet) {
            self.init(sheet: sheet, over: { PreviewBackground() })
        }
    }

    @MainActor
    @Observable
    final class SheetPreviewSizing {
        /// Same fallback as `ContentSizedSheetHostingController`, until the content is measured.
        private static var fallbackHeightFraction: CGFloat { 1 / 4 }

        var height: CGFloat?

        var detent: PresentationDetent {
            guard let height else {
                return .fraction(Self.fallbackHeightFraction)
            }

            return .height(height.rounded(.up))
        }
    }
#endif
