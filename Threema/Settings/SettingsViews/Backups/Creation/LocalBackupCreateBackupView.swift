import SwiftUI

struct LocalBackupCreateBackupView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let model: LocalBackupCreateBackupViewModel

    var body: some View {
        List {
            HeaderView(model: model)

            BackupInfoView(
                title: model.backupError?.title,
                content: model.backupError?.content,
                textColor: Color.red,
                textFont: .footnote,
                iconName: model.errorIconName,
                iconColor: Color.red
            )

            ExportsView(model: model)
            NoteView(note: model.note)
            BottomView(model: model, isVisible: isBottomViewInlined)
        }
        .navigationBarTitleDisplayMode(.inline)
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .safeAreaInset(edge: .bottom) {
            BottomView(model: model, isVisible: !isBottomViewInlined)
                .padding(.horizontal, 28)
        }
        .task {
            model.startBackup()
        }
    }

    private struct HeaderView: View {
        let model: LocalBackupCreateBackupViewModel

        var body: some View {
            BackupHeaderView(
                icon: .init(
                    symbolName: model.state.iconSymbolName,
                    color: {
                        switch model.state {
                        case .inProgress: .blue
                        case .complete: .green
                        case .failed: .red
                        }
                    }()
                ),
                step: model.headerStep,
                title: model.headerTitle,
                subtitle: model.headerSubtitle
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity)
            .padding(.bottom, model.state == .complete ? 12 : 0)
        }
    }

    private struct ExportsView: View {
        @ScaledMetric private var scaledMetric: CGFloat = 1.0

        let model: LocalBackupCreateBackupViewModel

        var body: some View {
            Section {
                VStack(alignment: .leading, spacing: 18 * scaledMetric) {
                    ForEach(model.exportItems) { item in
                        ExportItemView(item: item)
                    }
                }
            }
        }

        private struct ExportItemView: View {
            @ScaledMetric private var scaledMetric: CGFloat = 1.0
            @Environment(\.dynamicTypeSize) private var dynamicTypeSize

            let item: LocalBackupCreateBackupViewModel.ExportItem

            var body: some View {
                HStack(
                    alignment: dynamicTypeSize > .accessibility1 ? .top : .center,
                    spacing: 8 * scaledMetric
                ) {
                    IconView(state: item.state)

                    VStack(alignment: .leading, spacing: 4 * scaledMetric) {
                        Text(item.title)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Text(item.statusText)
                            .font(.subheadline)
                            .bold(item.state != .waiting)
                            .foregroundStyle(item.state == .failed ? .red : .secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            private struct IconView: View {
                @ScaledMetric private var scaledMetric: CGFloat = 32

                let state: LocalBackupCreateBackupViewModel.ExportItem.State

                var body: some View {
                    Image(systemName: state.symbolName)
                        .font(.system(size: scaledMetric * 15 / 32, weight: .bold))
                        .foregroundStyle(foregroundColor)
                        .apply { image in
                            if #available(iOS 18.0, *) {
                                image.symbolEffect(.rotate, isActive: state == .inProgress)
                            }
                            else {
                                image
                            }
                        }
                        .id(state) // needed for animation state
                        .frame(width: scaledMetric, height: scaledMetric)
                        .background(backgroundColor, in: .circle)
                }

                private var foregroundColor: Color {
                    switch state {
                    case .waiting: .white
                    case .failed: .red
                    case .done: .green
                    case .inProgress: .cyan
                    }
                }

                private var backgroundColor: Color {
                    switch state {
                    case .waiting: Color(.systemGray4)
                    case .done: .green.opacity(0.2)
                    case .inProgress: .cyan.opacity(0.2)
                    case .failed: .red.opacity(0.2)
                    }
                }
            }
        }
    }

    private struct NoteView: View {
        let note: String?

        var body: some View {
            if let note {
                Text(note)
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }

    private struct BottomView: View {
        let model: LocalBackupCreateBackupViewModel
        let isVisible: Bool

        var body: some View {
            if isVisible {
                Group {
                    switch model.state {
                    case .inProgress:
                        ThreemaButton(
                            title: model.cancelButtonTitle,
                            style: .bordered,
                            size: .fullWidth,
                            action: model.cancelButtonTapped
                        )
                    case .complete:
                        ThreemaButton(
                            title: model.doneButtonTitle,
                            style: .borderedProminent,
                            size: .fullWidth,
                            action: model.doneButtonTapped
                        )
                    case .failed:
                        VStack {
                            ThreemaButton(
                                title: model.tryAgainButtonTitle,
                                style: .borderedProminent,
                                size: .fullWidth,
                                action: model.tryAgainButtonTapped
                            )

                            ThreemaButton(
                                title: model.dismissButtonTitle,
                                style: .borderless,
                                size: .fullWidth,
                                action: model.dismissButtonTapped
                            )
                        }
                    }
                }
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

        case (.compact, .regular):
            return dynamicTypeSize >= DynamicTypeSize.xxLarge

        case (.regular, .regular):
            return dynamicTypeSize >= DynamicTypeSize.accessibility1

        default:
            return true
        }
    }
}

#if DEBUG
    import DataBackup
    import ThreemaMacros

    #Preview(LocalBackupCreateBackupView.Stance.inProgress.title) {
        LocalBackupCreateBackupView.Stance.inProgress.view
    }

    #Preview(LocalBackupCreateBackupView.Stance.complete.title) {
        LocalBackupCreateBackupView.Stance.complete.view
    }

    #Preview(LocalBackupCreateBackupView.Stance.failed.title) {
        LocalBackupCreateBackupView.Stance.failed.view
    }

    /// A backup that keeps advancing, to see the steps move.
    #Preview("Creating Backup - Running") {
        LocalBackupCreateBackupView(
            model: LocalBackupCreateBackupViewModel(
                manager: BackupCreateManagerMock(
                    currentRecoveryKey: .mockGeneratedKey,
                    createBehavior: .succeeding(
                        progress: DataBackupProgress.mockRun,
                        delay: .milliseconds(2000)
                    )
                )
            )
        )
    }

    extension LocalBackupCreateBackupView {
        enum Stance: PreviewCase {
            case inProgress
            case complete
            case failed

            var title: String {
                switch self {
                case .inProgress: "Creating Backup - In Progress"
                case .complete: "Creating Backup - Complete"
                case .failed: "Creating Backup - Failed"
                }
            }

            @MainActor var view: some View {
                LocalBackupCreateBackupView(model: makeModel())
            }

            @MainActor private func makeModel() -> LocalBackupCreateBackupViewModel {
                let model = LocalBackupCreateBackupViewModel(
                    manager: BackupCreateManagerMock(
                        currentRecoveryKey: .mockGeneratedKey,
                        createBehavior: .idle
                    )
                )

                switch self {
                case .inProgress:
                    model.apply(DataBackupProgress.mock(phase: .messages, itemsProcessed: 1284))

                case .complete:
                    model.apply(DataBackupProgress.mock(phase: .finalizing))
                    model.state = .complete

                case .failed:
                    model.apply(DataBackupProgress.mock(phase: .finalizing))
                    model.state = .failed
                    model.backupError = (
                        title: #localize("safe_backup_error_title"),
                        content: BackupCreateManagerMock.MockError.createFailed.localizedDescription
                    )
                }

                return model
            }
        }
    }
#endif
