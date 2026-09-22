import SwiftUI
import ThreemaFramework

struct LocalBackupRecoveryKeyConfirmationView: View {
    @Bindable var model: LocalBackupRecoveryKeyConfirmationViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @FocusState private var isTextFieldFocused: Bool

    private static let keyInputFieldID = "keyInputField"

    var body: some View {
        ScrollViewReader { proxy in
            List {
                HeaderView(model: model)

                KeyInputFieldView(
                    model: model,
                    isTextFieldFocused: $isTextFieldFocused
                )
                .id(Self.keyInputFieldID)

                BottomView(model: model, isVisible: isBottomViewInlined)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .listSectionSpacing(.compact)
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                BottomView(model: model, isVisible: !isBottomViewInlined)
                    .padding(.horizontal, 28)
                    .padding(.bottom, isTextFieldFocused ? 12 : 0)
            }
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: verticalSizeClass) {
                scrollToInputField(using: proxy, delay: 350)
            }
            .onChange(of: isTextFieldFocused) {
                scrollToInputField(using: proxy)
            }
            .onChange(of: model.message) {
                scrollToInputField(using: proxy)
            }
        }
    }

    private func scrollToInputField(using proxy: ScrollViewProxy, delay: Int = 100) {
        Task {
            // Wait for SwiftUI to finish the relayout the size-class change triggers before scrolling, otherwise
            // `scrollTo` runs against the stale layout and doesn't reach the bottom view.
            try? await Task.sleep(for: .milliseconds(delay))
            withAnimation {
                proxy.scrollTo(Self.keyInputFieldID, anchor: .bottom)
            }
        }
    }

    private struct HeaderView: View {
        let model: LocalBackupRecoveryKeyConfirmationViewModel

        var body: some View {
            BackupHeaderView(
                icon: .init(symbolName: model.symbolName, color: .blue, rotationDegrees: 30),
                step: model.stepLabel,
                title: model.keyTitle,
                subtitle: model.keyDescription
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity)
        }
    }

    private struct KeyInputFieldView: View {
        @Bindable var model: LocalBackupRecoveryKeyConfirmationViewModel
        @ScaledMetric private var scaledMetric: CGFloat = 1.0
        @FocusState.Binding var isTextFieldFocused: Bool

        var body: some View {
            Section {
                VStack(alignment: .leading, spacing: 10 * scaledMetric) {
                    Text(model.recoveryKeyHeader)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("", text: $model.enteredLastDigits, prompt: Text(model.prompt))
                        .font(.body)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isTextFieldFocused)
                        .frame(maxWidth: .infinity, minHeight: 80 * scaledMetric, alignment: .topLeading)
                        .padding(10 * scaledMetric)
                        .background(Color(.systemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12 * scaledMetric))
                        .contentShape(RoundedRectangle(cornerRadius: 12 * scaledMetric))

                    MessageView(message: model.message)
                }
            }
        }

        private struct MessageView: View {
            let message: LocalBackupRecoveryKeyConfirmationViewModel.MessageType

            var body: some View {
                switch message {
                case .none:
                    EmptyView()

                case let .success(text):
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(.green)

                case let .error(text):
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private struct BottomView: View {
        let model: LocalBackupRecoveryKeyConfirmationViewModel
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
}

#if DEBUG

    #Preview(LocalBackupRecoveryKeyConfirmationView.Stance.noInput.title) {
        LocalBackupRecoveryKeyConfirmationView.Stance.noInput.view
    }

    #Preview(LocalBackupRecoveryKeyConfirmationView.Stance.inputMatches.title) {
        LocalBackupRecoveryKeyConfirmationView.Stance.inputMatches.view
    }

    #Preview(LocalBackupRecoveryKeyConfirmationView.Stance.inputNotMatching.title) {
        LocalBackupRecoveryKeyConfirmationView.Stance.inputNotMatching.view
    }

    import DataBackup

    extension LocalBackupRecoveryKeyConfirmationView {
        enum Stance: PreviewCase {
            case noInput
            case inputMatches
            case inputNotMatching

            var title: String {
                switch self {
                case .noInput: "Recovery Key Confirmation"
                case .inputMatches: "Recovery Key Confirmation - Digits Matching"
                case .inputNotMatching: "Recovery Key Confirmation - Digits Not Matching"
                }
            }

            @MainActor var view: some View {
                switch self {
                case .noInput:
                    PushedPreview {
                        LocalBackupRecoveryKeyConfirmationView(
                            model: makeModel(lastDigits: "") // <--- No input
                        )
                    }

                case .inputMatches:
                    PushedPreview {
                        LocalBackupRecoveryKeyConfirmationView(
                            model: makeModel(lastDigits: "C3D4") // <--- Correct last digits input
                        )
                    }

                case .inputNotMatching:
                    PushedPreview {
                        LocalBackupRecoveryKeyConfirmationView(
                            model: makeModel(lastDigits: "1234") // <--- Wrong last digits input
                        )
                    }
                }
            }

            // MARK: - Helpers

            @MainActor
            private func makeModel(lastDigits: String) -> LocalBackupRecoveryKeyConfirmationViewModel {
                let model = LocalBackupRecoveryKeyConfirmationViewModel(
                    manager: BackupCreateManagerMock(currentRecoveryKey: .mockGeneratedKey)
                )
                model.enteredLastDigits = lastDigits
                return model
            }
        }
    }

#endif
