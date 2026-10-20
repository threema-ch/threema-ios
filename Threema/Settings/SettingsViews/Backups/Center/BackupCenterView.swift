import SwiftUI

struct BackupCenterView: View {
    let model: BackupCenterViewModel

    var body: some View {
        List {
            BackupSection(
                header: model.onlineSectionHeader,
                title: model.onlineTitle,
                subHeadline: model.onlineSubHeadline,
                statusIconName: model.statusIconName,
                statusText: model.safeStatusLabel,
                hasBackup: model.hasSafeBackup,
                learnMoreButtonTitle: model.learnMoreButtonTitle,
                action: { model.safeButtonTapped() },
                learnMoreAction: { model.safeLearnMoreButtonTapped() }
            )

            BackupSection(
                header: model.offlineSectionHeader,
                title: model.offlineTitle,
                subHeadline: model.offlineSubHeadline,
                statusIconName: model.statusIconName,
                statusText: model.localBackupStatus,
                hasBackup: model.hasLocalBackup,
                learnMoreButtonTitle: model.learnMoreButtonTitle,
                action: { model.localDataBackupDataButtonTapped() },
                learnMoreAction: { model.localDataBackupLearnMoreButtonTapped() }
            )
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(model.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.onAppear()
        }
    }

    private struct BackupSection: View {
        let header: String
        let title: String
        let subHeadline: String
        let statusIconName: String
        let statusText: String
        let hasBackup: Bool
        let learnMoreButtonTitle: String
        let action: () -> Void
        let learnMoreAction: () -> Void

        var body: some View {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    ButtonNavigation {
                        action()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(title)
                                .font(.title3)

                            Text(subHeadline)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)

                            BackupStatusLabel(
                                iconName: statusIconName,
                                text: statusText,
                                hasBackup: hasBackup
                            )
                        }
                        .padding(.trailing)
                    }
                    .frame(maxWidth: .infinity)
                }
                Button {
                    learnMoreAction()
                } label: {
                    Text(learnMoreButtonTitle)
                }
            } header: {
                Text(header)
            }
        }
    }

    private struct BackupStatusLabel: View {
        let iconName: String
        let text: String
        let hasBackup: Bool

        var body: some View {
            HStack {
                Image(systemName: iconName)
                    .font(.caption)
                    .foregroundStyle(hasBackup ? .green : Color(.tertiaryLabel))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(hasBackup ? .green : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
    import ThreemaFramework

    #Preview(BackupCenterView.Stance.noBackup.title) {
        BackupCenterView.Stance.noBackup.view
    }

    #Preview(BackupCenterView.Stance.backup.title) {
        BackupCenterView.Stance.backup.view
    }

    #Preview(BackupCenterView.Stance.learnMoreBackup.title) {
        BackupCenterView.Stance.learnMoreBackup.view
    }

    #Preview(BackupCenterView.Stance.learnMoreSafe.title) {
        BackupCenterView.Stance.learnMoreSafe.view
    }

    extension BackupCenterView {
        enum Stance: PreviewCase {
            case noBackup
            case backup
            case learnMoreBackup
            case learnMoreSafe

            var title: String {
                switch self {
                case .noBackup: "Backup Center - No Backup"
                case .backup: "Backup Center - Backup Details"
                case .learnMoreBackup: "Backup Center - Learn More Backup"
                case .learnMoreSafe: "Backup Center - Learn More Threema Safe"
                }
            }

            private func makeManager(hasBackup: Bool = false) -> any BackupCreateManagerProtocol {
                let mock = BackupCreateManagerMock(createBehavior: .immediateSuccess)
                if !hasBackup {
                    mock.lastBackup = nil
                }
                return mock
            }

            @MainActor
            private func makeCenter(
                hasBackup: Bool = false,
                safeManager: any SafeManagerProtocol = .deactivated,
                safeConfigManager: any SafeConfigManagerProtocol = .noBackup,
                appFlavor: any AppFlavorServiceProtocol = .mock
            ) -> some View {
                PushedPreview(rootTitle: "Settings") {
                    BackupCenterView(
                        model: BackupCenterViewModel(
                            appFlavor: appFlavor,
                            backupManager: makeManager(hasBackup: hasBackup),
                            safeManager: safeManager,
                            safeConfigManager: safeConfigManager
                        )
                    )
                }
            }

            @MainActor var view: some View {
                switch self {
                case .noBackup:
                    makeCenter()

                case .backup:
                    makeCenter(hasBackup: true, safeManager: .activated, safeConfigManager: .backupSucceeded)

                case .learnMoreBackup:
                    SheetPreview {
                        LearnMoreSheetView(model: LocalBackupLearnMoreViewModel())
                    } over: {
                        makeCenter()
                    }

                case .learnMoreSafe:
                    SheetPreview {
                        LearnMoreSheetView(model: ThreemaSafeLearnMoreViewModel(appFlavor: .blue))
                    } over: {
                        makeCenter(appFlavor: .blue)
                    }
                }
            }
        }
    }
#endif
