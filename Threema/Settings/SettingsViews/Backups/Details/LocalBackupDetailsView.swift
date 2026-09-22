import SwiftUI

struct LocalBackupDetailsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let model: LocalBackupDetailsViewModel

    var body: some View {
        List {
            DetailsSection(model: model)
            ActionsSection(model: model)
            BottomView(model: model, isVisible: isBottomViewInlined)
        }
        .navigationTitle(model.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            BottomView(model: model, isVisible: !isBottomViewInlined)
                .padding(.horizontal, 28)
                .padding(.bottom)
        }
    }

    private struct DetailsSection: View {
        let model: LocalBackupDetailsViewModel

        var body: some View {
            Section {
                ForEach(model.detailItems) { item in
                    RowView(item: item)
                }
            }
        }

        private struct RowView: View {
            let item: LocalBackupDetailsViewModel.DetailItem

            var body: some View {
                AdaptiveStack {
                    Text(item.label)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(item.value)
                        .foregroundStyle(item.isValueHighlighted ? Color.green : Color.secondary)
                }
            }
        }
    }

    private struct ActionsSection: View {
        let model: LocalBackupDetailsViewModel

        var body: some View {
            Section {
                ShareRow(model: model)
                if model.isRecoveryKeyNavigationVisible {
                    ButtonNavigation {
                        model.keyActionButtonTapped()
                    } label: {
                        Text(model.keyActionTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }

        private struct ShareRow: View {
            let model: LocalBackupDetailsViewModel

            var body: some View {
                HStack {
                    Text(model.shareActionTitle)
                    Spacer()
                    ShareLink(item: model.shareURL) {
                        Image(systemName: model.shareActionIconName)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
    }

    private struct BottomView: View {
        let model: LocalBackupDetailsViewModel
        let isVisible: Bool

        var body: some View {
            if isVisible {
                ThreemaButton(
                    title: model.buttonTitle,
                    style: .borderedProminent,
                    size: .fullWidth,
                    action: {
                        model.createButtonTapped()
                    }
                )
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
    import ThreemaFramework

    #Preview(LocalBackupDetailsView.Stance.details.title) {
        LocalBackupDetailsView.Stance.details.view
    }

    extension LocalBackupDetailsView {
        enum Stance: PreviewCase {
            case details
            case detailsKeyRemoved

            var title: String {
                switch self {
                case .details: "Backup Details - Default Key"
                case .detailsKeyRemoved: "Backup Details - Key Removed"
                }
            }

            @MainActor var view: some View {
                switch self {
                case .details:
                    PushedPreview(rootTitle: "Backups") {
                        LocalBackupDetailsView(
                            model: LocalBackupDetailsViewModel(
                                manager: BackupCreateManagerMock(
                                    currentRecoveryKey: .mockDefaultKey
                                )
                            )
                        )
                    }

                case .detailsKeyRemoved:
                    PushedPreview(rootTitle: "Backups") {
                        LocalBackupDetailsView(
                            model: LocalBackupDetailsViewModel(
                                manager: BackupCreateManagerMock(
                                    currentRecoveryKey: .mockGeneratedKey
                                )
                            )
                        )
                    }
                }
            }
        }
    }
#endif
