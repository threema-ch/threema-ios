#if DEBUG
    import SwiftUI

    struct SheetPreview<Sheet: View, Background: View>: View {
        private let sheet: Sheet
        private let background: Background

        @State private var isPresented = true

        init(@ViewBuilder sheet: () -> Sheet, @ViewBuilder over background: () -> Background) {
            self.sheet = sheet()
            self.background = background()
        }

        var body: some View {
            background
                .sheet(isPresented: $isPresented) {
                    sheet
                }
                .transaction { transaction in
                    transaction.disablesAnimations = true
                }
        }
    }

    extension SheetPreview where Background == PreviewBackground {
        init(@ViewBuilder sheet: () -> Sheet) {
            self.init(sheet: sheet, over: { PreviewBackground() })
        }
    }

    struct PreviewBackground: View {
        var body: some View {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        }
    }
#endif
