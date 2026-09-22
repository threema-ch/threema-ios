import SwiftUI
import ThreemaFramework

struct LocalBackupRecoveryKeyEntryView: View {
    @Bindable var model: LocalBackupRecoveryKeyEntryViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        List {
            HeaderView(model: model)
            KeyInputFieldView(model: model, isTextFieldFocused: $isTextFieldFocused)
            BottomView(model: model, isVisible: isBottomViewInlined)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            BottomView(model: model, isVisible: !isBottomViewInlined)
                .padding(.horizontal, 28)
                .padding(.bottom, isTextFieldFocused ? 12 : 0)
        }
        .task {
            isTextFieldFocused = true
        }
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

    private struct HeaderView: View {
        let model: LocalBackupRecoveryKeyEntryViewModel

        var body: some View {
            BackupHeaderView(
                icon: .init(symbolName: model.symbolName, color: .blue, rotationDegrees: 30),
                step: nil,
                title: model.headerTitle,
                subtitle: model.headerSubtitle
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity)
        }
    }

    private struct KeyInputFieldView: View {
        @Bindable var model: LocalBackupRecoveryKeyEntryViewModel
        @ScaledMetric private var scaledMetric: CGFloat = 1.0
        @FocusState.Binding var isTextFieldFocused: Bool

        var body: some View {
            Section {
                VStack(alignment: .leading, spacing: 10 * scaledMetric) {
                    Text(model.keyFieldHeader)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("", text: $model.enteredKey, axis: .vertical)
                        .font(.body)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isTextFieldFocused)
                        .frame(maxWidth: .infinity, minHeight: 80 * scaledMetric, alignment: .topLeading)
                        .padding(10 * scaledMetric)
                        .background(Color(.systemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12 * scaledMetric))
                        .contentShape(RoundedRectangle(cornerRadius: 12 * scaledMetric))
                }
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
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }
}

#if DEBUG

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
                    model.enteredKey = String(repeating: "A1B2C3D4", count: 8)
                }

                return model
            }
        }
    }

#endif
