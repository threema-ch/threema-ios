import DataBackup
import SwiftUI

struct LocalBackupSettingsView: View {
    @Bindable var model: LocalBackupSettingsViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        List {
            HeaderView(model: model)
            RecoveryKeySection(model: model)
            AlwaysIncludedSection(model: model)
            IncludeMediaSection(model: model)
            BottomView(model: model, isVisible: isBottomViewInlined)
        }
        .navigationBarTitleDisplayMode(.inline)
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .safeAreaInset(edge: .bottom) {
            BottomView(model: model, isVisible: !isBottomViewInlined)
                .padding(.horizontal, 28)
        }
        .alert(
            model.notEnoughStorageTitle,
            isPresented: $model.showNotEnoughStorageAlert
        ) {
            Button(model.freeUpSpaceButtonTitle) {
                model.freeUpSpaceTapped()
            }

            Button(model.excludeMediaButtonTitle) {
                model.excludeMediaTapped()
            }
            Button(model.cancelButtonTitle, role: .cancel) {
                model.cancelButtonTapped()
            }
        } message: {
            Text(verbatim: model.notEnoughStorageMessage)
        }
    }

    private struct HeaderView: View {
        let model: LocalBackupSettingsViewModel

        var body: some View {
            BackupHeaderView(
                icon: .init(symbolName: model.symbolName, color: .blue),
                step: model.stepLabel,
                title: model.headerTitle,
                subtitle: model.headerDescription
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity)
        }
    }

    private struct RecoveryKeySection: View {
        let model: LocalBackupSettingsViewModel

        var body: some View {
            if model.isDefaultKey {
                Section {
                    ButtonNavigation {
                        model.recoveryKeyDetailsButtonTapped()
                    } label: {
                        AdaptiveStack {
                            Text(model.recoveryKeyLabel)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(model.recoveryKeyTrimmed)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.leading)
                    }
                } header: {
                    Text(model.recoveryKeySectionHeader)
                }
            }
        }
    }

    private struct AlwaysIncludedSection: View {
        let model: LocalBackupSettingsViewModel

        var body: some View {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(verbatim: model.includedMessagesTitle)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Text(verbatim: model.includedMessagesSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if model.isDefaultKey {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text(verbatim: model.includedSectionHeader)
            } footer: {
                Text(verbatim: model.includedSectionFooter)
            }
        }
    }

    private struct IncludeMediaSection: View {
        @Bindable var model: LocalBackupSettingsViewModel

        var body: some View {
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Toggle(isOn: $model.includeMedia) {
                            Text(verbatim: model.includeMediaTitle)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Text(verbatim: model.includeMediaSubtitle)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .tint(Color.accentColor)
                    }

                    if model.includeMedia {
                        Divider()

                        Text(verbatim: model.whatsIncludedLabel)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.mediaItems) { item in
                                RowView(
                                    iconName: item.iconName,
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    isDefaultKey: model.isDefaultKey
                                )
                            }
                        }
                    }
                }
            } header: {
                Text(verbatim: model.mediaSectionHeader)
            } footer: {
                Text(verbatim: model.mediaSectionFooter)
            }
        }

        private struct RowView: View {
            @ScaledMetric private var scaledMetric: CGFloat = 1.0

            let iconName: String
            let title: String
            let subtitle: String
            let isDefaultKey: Bool

            var body: some View {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: iconName)
                        .resizable()
                        .symbolRenderingMode(.monochrome)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16 * scaledMetric, height: 16 * scaledMetric)

                    VStack(alignment: .leading) {
                        Text(verbatim: title)
                            .font(.body)
                            .foregroundStyle(.primary)

                        // TODO: Check if this is still needed?
                        Text(verbatim: subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isDefaultKey {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    private struct BottomView: View {
        let model: LocalBackupSettingsViewModel
        let isVisible: Bool

        var body: some View {
            Group {
                if isVisible {
                    ThreemaButton(
                        title: model.startButtonTitle,
                        style: .borderedProminent,
                        size: .fullWidth
                    ) {
                        model.startButtonTapped()
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
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
    #Preview(LocalBackupSettingsView.Stance.generatedKey.title) {
        LocalBackupSettingsView.Stance.generatedKey.view
    }

    #Preview(LocalBackupSettingsView.Stance.defaultKey.title) {
        LocalBackupSettingsView.Stance.defaultKey.view
    }

    #Preview(LocalBackupSettingsView.Stance.generatedKeyIncludeMediaOff.title) {
        LocalBackupSettingsView.Stance.generatedKeyIncludeMediaOff.view
    }

    #Preview(LocalBackupSettingsView.Stance.space.title) {
        LocalBackupSettingsView.Stance.space.view
    }

    extension LocalBackupSettingsView {
        enum Stance: PreviewCase {
            case generatedKey
            case defaultKey
            case generatedKeyIncludeMediaOff
            case defaultKeyIncludeMediaOff
            case space

            var title: String {
                switch self {
                case .generatedKey: "Backup Settings - Generated Key"
                case .defaultKey: "Backup Settings - Default Key"
                case .generatedKeyIncludeMediaOff: "Backup Settings - Generated Key - Media Off"
                case .defaultKeyIncludeMediaOff: "Backup Settings - Default Key - Media Off"
                case .space: "Backup Settings - Alert Not enough space"
                }
            }

            @MainActor var view: some View {
                switch self {
                case .generatedKey:
                    PushedPreview {
                        LocalBackupSettingsView(
                            model: LocalBackupSettingsViewModel(
                                manager: BackupCreateManagerMock(currentRecoveryKey: .mockGeneratedKey)
                            )
                        )
                    }
                case .defaultKey:
                    PushedPreview {
                        LocalBackupSettingsView(
                            model: LocalBackupSettingsViewModel(
                                manager: BackupCreateManagerMock(currentRecoveryKey: .mockDefaultKey)
                            )
                        )
                    }
                case .generatedKeyIncludeMediaOff:
                    PushedPreview {
                        LocalBackupSettingsView(
                            model: {
                                let model = LocalBackupSettingsViewModel(
                                    manager: BackupCreateManagerMock(currentRecoveryKey: .mockGeneratedKey)
                                )
                                model.includeMedia = false
                                return model
                            }()
                        )
                    }
                case .defaultKeyIncludeMediaOff:
                    PushedPreview {
                        LocalBackupSettingsView(
                            model: {
                                let model = LocalBackupSettingsViewModel(
                                    manager: BackupCreateManagerMock(currentRecoveryKey: .mockDefaultKey)
                                )
                                model.includeMedia = false
                                return model
                            }()
                        )
                    }
                case .space:
                    PushedPreview {
                        let model = LocalBackupSettingsViewModel(
                            manager: BackupCreateManagerMock(currentRecoveryKey: .mockGeneratedKey)
                        )
                        LocalBackupSettingsView(model: model)
                            .task {
                                model.showNotEnoughStorageAlert = true
                            }
                    }
                }
            }
        }
    }

#endif
