import SwiftUI

struct BackupCenterView: View {
    let model: BackupCenterViewModel

    var body: some View {
        List {
            OnlineSection(model: model)
            OfflineSection(model: model)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(model.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.onAppear()
        }
    }

    private struct OnlineSection: View {
        let model: BackupCenterViewModel

        var body: some View {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    ButtonNavigation {
                        model.safeButtonTapped()
                    } label: {
                        HStack {
                            Text(model.onlineTitle)
                                .font(.title3)
                            Spacer()
                            Text(model.safeStatusLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(model.onlineSubHeadline)
                        .font(.subheadline)
                }
                Button {
                    model.safeLearnMoreButtonTapped()
                } label: {
                    Text(model.learnMoreButtonTitle)
                }
            } header: {
                Text(model.onlineSectionHeader)
            }
        }
    }

    private struct OfflineSection: View {
        let model: BackupCenterViewModel

        var body: some View {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    ButtonNavigation {
                        model.localDataBackupDataButtonTapped()
                    } label: {
                        HStack {
                            Text(model.offlineTitle)
                                .font(.title3)
                            Spacer()
                        }
                    }
                    Text(model.offlineSubHeadline)
                        .font(.subheadline)

                    Text(model.offlineBackupStatus)
                        .font(.body)
                        .foregroundStyle(model.hasLastBackup ? Color.accentColor : .secondary)
                        .padding(.top, 8)
                }
                Button {
                    model.localDataBackupLearnMoreButtonTapped()
                } label: {
                    Text(model.learnMoreButtonTitle)
                }
            } header: {
                Text(model.offlineSectionHeader)
            }
        }
    }
}

#if DEBUG

    #Preview(BackupCenterView.Stance.noBackup.title) {
        BackupCenterView.Stance.noBackup.view
    }

    #Preview(BackupCenterView.Stance.backup.title) {
        BackupCenterView.Stance.backup.view
    }

    extension BackupCenterView {
        enum Stance: PreviewCase {
            case noBackup
            case backup

            var title: String {
                switch self {
                case .noBackup: "Backup Center - No Backup"
                case .backup: "Backup Center - Backup Details"
                }
            }

            private func makeManager(hasBackup: Bool = false) -> any BackupCreateManagerProtocol {
                let mock = BackupCreateManagerMock(createBehavior: .immediateSuccess)
                if !hasBackup {
                    mock.lastBackup = nil
                }
                return mock
            }

            @MainActor var view: some View {
                switch self {
                case .noBackup:
                    PushedPreview(rootTitle: "Settings") {
                        BackupCenterView(
                            model: BackupCenterViewModel(
                                appFlavor: .mock,
                                manager: makeManager(),
                                safeManager: .deactivated
                            )
                        )
                    }

                case .backup:
                    PushedPreview(rootTitle: "Settings") {
                        BackupCenterView(
                            model: BackupCenterViewModel(
                                appFlavor: .mock,
                                manager: makeManager(hasBackup: true),
                                safeManager: .activated
                            )
                        )
                    }
                }
            }
        }
    }
#endif
