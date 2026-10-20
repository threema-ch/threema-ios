import SwiftUI
import ThreemaFramework

struct LocalBackupRecoveryKeyEntryView: View {
    @Bindable var model: LocalBackupRecoveryKeyEntryViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @FocusState private var focusedComponent: Int?
    @ScaledMetric private var scaledMetric: CGFloat = 1.0

    private let headerHeight = DotHeaderView.defaultHeight
    private let headerOverlap = DotHeaderView.defaultOverlap

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DotHeaderView(
                    icon: DotHeaderView.Icon(name: model.headerIconName, color: .accentColor),
                    dotColor: .accentColor.opacity(0.3),
                    height: headerHeight
                )

                VStack(spacing: 10 * scaledMetric) {
                    BackupHeaderView(
                        step: nil,
                        title: model.headerTitle,
                        subtitle: model.headerSubtitle,
                        backdrop: Color.listsBackgroundColor
                    )
                    .padding(.bottom, 20 * scaledMetric)

                    KeyView(model: model, focusedComponent: $focusedComponent)

                    BottomView(model: model, isVisible: isBottomViewInlined)
                }
                .safeAreaPadding(.horizontal, 20)
                .padding(.top, -headerHeight * headerOverlap / scaledMetric)
            }
        }
        .background(Color.listsBackgroundColor.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            BottomView(model: model, isVisible: !isBottomViewInlined)
                .padding(.horizontal, 28)
                .padding(.bottom, isKeyFieldFocused ? 12 : 0)
        }
        .task {
            focusedComponent = model.focusedComponent
        }
    }

    private var isKeyFieldFocused: Bool {
        focusedComponent != nil
    }

    private var isBottomViewInlined: Bool {
        guard let horizontalSizeClass, let verticalSizeClass else {
            return true
        }

        switch (horizontalSizeClass, verticalSizeClass) {
        case (_, .compact):
            return true

        case (_, .regular):
            return dynamicTypeSize >= DynamicTypeSize.accessibility1

        default:
            return true
        }
    }

    private struct KeyView: View {
        @ScaledMetric private var scaledMetric: CGFloat = 1.0
        @Bindable var model: LocalBackupRecoveryKeyEntryViewModel
        @FocusState.Binding var focusedComponent: Int?

        var body: some View {
            SectionCard {
                GridView(model: model, focusedComponent: $focusedComponent)
                    .padding(.vertical, 8 * scaledMetric)
            } header: {
                Text(model.sectionHeader)
            }
        }
    }

    private struct GridView: View {
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.verticalSizeClass) private var verticalSizeClass
        @ScaledMetric private var scaledMetric: CGFloat = 1.0

        let model: LocalBackupRecoveryKeyEntryViewModel
        @FocusState.Binding var focusedComponent: Int?

        var body: some View {
            Grid(horizontalSpacing: 0, verticalSpacing: 24 * scaledMetric) {
                ForEach(model.keyRows(columnsPerRow: columnsPerRow)) { row in
                    GridRow {
                        ForEach(row.cells) { cell in
                            KeyFieldView(
                                model: model,
                                index: cell.index,
                                text: cell.text,
                                focusedComponent: $focusedComponent
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .onChange(of: model.focusedComponent) { _, newValue in
                focusedComponent = newValue
            }
            .onChange(of: focusedComponent) { _, newValue in
                guard let newValue, newValue != model.focusedComponent else {
                    return
                }

                focusedComponent = model.focusedComponent
            }
        }

        private var columnsPerRow: Int {
            guard let horizontalSizeClass, let verticalSizeClass else {
                return 1
            }

            return switch (horizontalSizeClass, verticalSizeClass) {
            case (_, .compact):
                dynamicTypeSize > .accessibility4 ? 2 : 4

            case (.compact, .regular):
                if dynamicTypeSize > .accessibility2 {
                    1
                }
                else if dynamicTypeSize > .xxxLarge {
                    2
                }
                else {
                    4
                }

            case (.regular, .regular):
                4

            default:
                1
            }
        }

        private struct KeyFieldView: View {
            let model: LocalBackupRecoveryKeyEntryViewModel
            let index: Int
            let text: String
            @FocusState.Binding var focusedComponent: Int?
            @State private var fieldText = ""

            var body: some View {
                Text(model.widestComponent)
                    .font(font)
                    .lineLimit(1)
                    .hidden()
                    .overlay {
                        TextField(model.componentPlaceholder, text: $fieldText)
                            .font(font)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .focused($focusedComponent, equals: index)
                    }
                    .frame(maxWidth: .infinity)
                    .onChange(of: text, initial: true) { _, newValue in
                        fieldText = newValue
                    }
                    .onChange(of: fieldText) { _, newValue in
                        guard newValue != model.component(at: index) else {
                            return
                        }

                        model.updateComponent(newValue, at: index)
                        fieldText = model.component(at: index)
                    }
            }

            private var font: Font {
                .callout.weight(.medium)
            }
        }
    }

    private struct BottomView: View {
        let model: LocalBackupRecoveryKeyEntryViewModel
        let isVisible: Bool

        var body: some View {
            if isVisible {
                ThreemaButton(
                    title: model.continueButtonTitle,
                    style: .borderedProminent,
                    size: .fullWidth
                ) {
                    model.continueButtonTapped()
                }
                .disabled(model.isContinueButtonDisabled)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#if DEBUG
    import DataBackup

    #Preview(LocalBackupRecoveryKeyEntryView.Stance.empty.title) {
        LocalBackupRecoveryKeyEntryView.Stance.empty.view
    }

    #Preview(LocalBackupRecoveryKeyEntryView.Stance.filled.title) {
        LocalBackupRecoveryKeyEntryView.Stance.filled.view
    }

    extension LocalBackupRecoveryKeyEntryView {
        enum Stance: PreviewCase {
            case empty
            case filled

            var title: String {
                switch self {
                case .empty: "Restore Recovery Key - Empty"
                case .filled: "Restore Recovery Key - Filled"
                }
            }

            @MainActor var view: some View {
                PushedPreview {
                    LocalBackupRecoveryKeyEntryView(model: makeModel())
                }
            }

            // MARK: - Helpers

            @MainActor
            private func makeModel() -> LocalBackupRecoveryKeyEntryViewModel {
                let model = LocalBackupRecoveryKeyEntryViewModel()

                switch self {
                case .empty:
                    break

                case .filled:
                    model.recoveryKey = BackupEncryptionKey.mockGeneratedKey.rawValue
                }

                return model
            }
        }
    }

#endif
