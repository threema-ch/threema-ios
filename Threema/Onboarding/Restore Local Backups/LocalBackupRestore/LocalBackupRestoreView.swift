import SwiftUI
import ThreemaFramework

struct LocalBackupRestoreView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let model: LocalBackupRestoreViewModel

    var body: some View {
        List {
            HeaderView(model: model)
            RestoreItemsView(model: model)

            BackupInfoView(
                title: model.restoreError?.title,
                content: model.restoreError?.content,
                textColor: Color.red,
                textFont: .footnote,
                iconName: model.errorIconName,
                iconColor: Color.red
            )

            BottomView(model: model, isVisible: isBottomViewInlined)
        }
        .scrollBounceBehavior(.basedOnSize)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .safeAreaInset(edge: .bottom) {
            BottomView(model: model, isVisible: !isBottomViewInlined)
                .padding(.horizontal, 28)
        }
        .task {
            model.startRestore()
        }
    }

    private var isBottomViewInlined: Bool {
        guard let horizontalSizeClass, let verticalSizeClass else {
            return true
        }

        switch (horizontalSizeClass, verticalSizeClass) {
        case (_, .compact):
            return dynamicTypeSize >= DynamicTypeSize.accessibility1

        case (.compact, .regular):
            return dynamicTypeSize >= DynamicTypeSize.accessibility4

        case (.regular, .regular):
            return false

        default:
            return true
        }
    }

    private struct HeaderView: View {
        let model: LocalBackupRestoreViewModel

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
                step: nil,
                title: model.headerTitle,
                subtitle: model.headerSubtitle
            )
            .padding(.bottom)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity)
        }
    }

    private struct RestoreItemsView: View {
        @ScaledMetric private var scaledMetric: CGFloat = 1.0

        let model: LocalBackupRestoreViewModel

        var body: some View {
            Section {
                VStack(alignment: .leading, spacing: 18 * scaledMetric) {
                    ForEach(model.restoreItems) { item in
                        RestoreItemView(item: item)
                    }
                }
            }
        }

        private struct RestoreItemView: View {
            @ScaledMetric private var scaledMetric: CGFloat = 1.0
            @Environment(\.dynamicTypeSize) private var dynamicTypeSize

            let item: LocalBackupRestoreViewModel.RestoreItem

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

                        Text(item.state.label)
                            .font(.subheadline)
                            .bold(item.state != .waiting)
                            .foregroundStyle(item.state == .failed ? .red : .secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            private struct IconView: View {
                @ScaledMetric private var scaledMetric: CGFloat = 32

                let state: LocalBackupRestoreViewModel.RestoreItem.State

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

    private struct BottomView: View {
        let model: LocalBackupRestoreViewModel
        let isVisible: Bool

        var body: some View {
            if isVisible, model.state == .failed {
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
                        action: model.dimissButtonTapped
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#if DEBUG
    import DataBackup

    #Preview(LocalBackupRestoreView.Stance.inProgress.title) {
        LocalBackupRestoreView.Stance.inProgress.view
    }

    #Preview(LocalBackupRestoreView.Stance.complete.title) {
        LocalBackupRestoreView.Stance.complete.view
    }

    #Preview(LocalBackupRestoreView.Stance.failed.title) {
        LocalBackupRestoreView.Stance.failed.view
    }

    /// A restore that keeps advancing, to see the steps move.
    #Preview("Restoring Backup - Running") {
        LocalBackupRestoreView(
            model: LocalBackupRestoreViewModel(state: .inProgress) { onProgress in
                for progress in DataRestoreProgress.mockRun.dropFirst() {
                    try await Task.sleep(for: .milliseconds(2000))
                    onProgress(progress)
                }

                try await Task.sleep(for: .seconds(60 * 60))
            }
        )
    }

    extension LocalBackupRestoreView {
        enum Stance: PreviewCase {
            case inProgress
            case complete
            case failed

            var title: String {
                switch self {
                case .inProgress: "Restoring Backup - In Progress"
                case .complete: "Restoring Backup - Complete"
                case .failed: "Restoring Backup - Failed"
                }
            }

            @MainActor var view: some View {
                LocalBackupRestoreView(model: makeModel())
            }

            // MARK: - Helpers

            /// The view starts the restore in `.task`, so each stance needs a restore that leaves the screen in the
            /// state the canvas is meant to show.
            @MainActor
            private func makeModel() -> LocalBackupRestoreViewModel {
                switch self {
                case .inProgress:
                    return LocalBackupRestoreViewModel(state: .inProgress) { onProgress in
                        onProgress(.mock(phase: .messages))

                        // Never finishes, so the screen stays in progress.
                        try await Task.sleep(for: .seconds(60 * 60))
                    }

                case .complete:
                    return LocalBackupRestoreViewModel(state: .complete)

                case .failed:
                    let model = LocalBackupRestoreViewModel(state: .failed) { _ in
                        throw PreviewRestoreError.failed
                    }
                    model.apply(.mock(phase: .polls))

                    return model
                }
            }
        }

        private enum PreviewRestoreError: Error {
            case failed
        }
    }
#endif
