import SwiftUI
import ThreemaFramework

struct LocalBackupRecoveryKeyConfirmationView: View {
    private static let keyInputFieldID = "keyInputField"

    @Bindable var model: LocalBackupRecoveryKeyConfirmationViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @FocusState private var isTextFieldFocused: Bool
    @ScaledMetric private var scaledMetric: CGFloat = 1.0

    private let headerHeight = DotHeaderView.defaultHeight
    private let headerOverlap = DotHeaderView.defaultOverlap

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    DotHeaderView(
                        icon: DotHeaderView.Icon(name: model.headerIconName, color: .accentColor),
                        dotColor: .accentColor.opacity(0.3),
                        height: headerHeight
                    )

                    VStack(spacing: 10 * scaledMetric) {
                        BackupHeaderView(
                            step: model.stepLabel,
                            title: model.headerTitle,
                            subtitle: model.headerSubtitle,
                            backdrop: Color.listsBackgroundColor
                        )
                        .padding(.bottom, 20 * scaledMetric)

                        KeyInputFieldView(model: model, isTextFieldFocused: $isTextFieldFocused)
                            .id(Self.keyInputFieldID)

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
            // Wait for SwiftUI to finish the relayout the size-class change triggers before scrolling,
            // otherwise `scrollTo` runs against the stale layout and doesn't reach the bottom view.
            try? await Task.sleep(for: .milliseconds(delay))
            withAnimation {
                proxy.scrollTo(Self.keyInputFieldID, anchor: .bottom)
            }
        }
    }

    private struct KeyInputFieldView: View {
        @Bindable var model: LocalBackupRecoveryKeyConfirmationViewModel
        @FocusState.Binding var isTextFieldFocused: Bool

        var body: some View {
            SectionCard {
                HStack {
                    TextField("", text: $model.enteredLastDigits, prompt: Text(model.prompt))
                        .font(.body.weight(.medium))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isTextFieldFocused)
                        .frame(maxWidth: .infinity)

                    IconView(message: model.message)
                }
            } header: {
                Text(model.recoveryKeyHeader)
            } footer: {
                MessageView(message: model.message)
            }
        }

        private struct IconView: View {
            let message: LocalBackupRecoveryKeyConfirmationViewModel.MessageType

            var body: some View {
                switch message {
                case .none:
                    EmptyView()

                case .error:
                    icon(systemName: "xmark.circle.fill", color: .red)

                case .success:
                    icon(systemName: "checkmark.circle.fill", color: .green)
                }
            }

            private func icon(systemName: String, color: Color) -> some View {
                Image(systemName: systemName)
                    .font(.body)
                    .foregroundStyle(color)
            }
        }

        private struct MessageView: View {
            let message: LocalBackupRecoveryKeyConfirmationViewModel.MessageType

            var body: some View {
                switch message {
                case .none, .success:
                    EmptyView()

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
                            model: makeModel(
                                lastDigits: String(BackupEncryptionKey.mockGeneratedKey.rawValue.suffix(4))
                            )
                        )
                    }

                case .inputNotMatching:
                    PushedPreview {
                        LocalBackupRecoveryKeyConfirmationView(
                            model: makeModel(lastDigits: "1234")
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
