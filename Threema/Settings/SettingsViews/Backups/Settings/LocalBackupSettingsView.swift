import DataBackup
import SwiftUI

struct LocalBackupSettingsView: View {
    @Bindable var model: LocalBackupSettingsViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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
                        step: model.stepLabel,
                        title: model.headerTitle,
                        subtitle: model.headerSubtitle,
                        backdrop: Color.listsBackgroundColor
                    )
                    .padding(.bottom, 20 * scaledMetric)

                    RecoveryKeySection(model: model)
                    AlwaysIncludedSection(model: model)
                    IncludeMediaSection(model: model)
                    BottomView(model: model, isVisible: isBottomViewInlined)
                }
                .safeAreaPadding(.horizontal, 20)
                .padding(.top, -headerHeight * headerOverlap / scaledMetric)
            }
        }
        .background(Color.listsBackgroundColor.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
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
            Text(model.notEnoughStorageMessage)
        }
    }

    private struct RecoveryKeySection: View {
        let model: LocalBackupSettingsViewModel

        var body: some View {
            if model.isDefaultKey {
                SectionCard {
                    Button {
                        model.recoveryKeyDetailsButtonTapped()
                    } label: {
                        HStack {
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

                            Image(systemName: model.disclosureIconName)
                                .foregroundStyle(.tertiary)
                                .imageScale(.small)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(model.recoveryKeySectionHeader)
                }
            }
        }
    }

    private struct AlwaysIncludedSection: View {
        let model: LocalBackupSettingsViewModel

        var body: some View {
            SectionCard {
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.includedMessagesTitle)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(model.includedMessagesSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if model.isDefaultKey {
                        Spacer()
                        Image(systemName: model.checkmarkIconName)
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text(model.includedSectionHeader)
            } footer: {
                Text(model.includedSectionFooter)
            }
        }
    }

    private struct IncludeMediaSection: View {
        @Bindable var model: LocalBackupSettingsViewModel

        var body: some View {
            SectionCard {
                VStack(alignment: .leading) {
                    HStack {
                        Toggle(isOn: $model.includeMedia) {
                            Text(model.includeMediaTitle)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Text(model.includeMediaSubtitle)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .tint(Color.accentColor)
                    }

                    if model.includeMedia {
                        Divider()
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.mediaItems) { item in
                                RowView(
                                    iconName: item.iconName,
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    isDefaultKey: model.isDefaultKey,
                                    checkmarkIconName: model.checkmarkIconName
                                )
                            }
                        }
                    }
                }
            } header: {
                Text(model.mediaSectionHeader)
            } footer: {
                Text(model.mediaSectionFooter)
            }
        }

        private struct RowView: View {
            @ScaledMetric private var scaledMetric: CGFloat = 1.0

            let iconName: String
            let title: String
            let subtitle: String
            let isDefaultKey: Bool
            let checkmarkIconName: String

            var body: some View {
                HStack(spacing: 16) {
                    Image(systemName: iconName)
                        .resizable()
                        .symbolRenderingMode(.monochrome)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22 * scaledMetric, height: 22 * scaledMetric)

                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.body)
                            .foregroundStyle(.primary)

                        // TODO: Check if this is still needed?
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isDefaultKey {
                        Spacer()
                        Image(systemName: checkmarkIconName)
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
            if isVisible {
                ThreemaButton(
                    title: model.startButtonTitle,
                    style: .borderedProminent,
                    size: .fullWidth
                ) {
                    model.startButtonTapped()
                }
                .frame(maxWidth: .infinity, alignment: .center)
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

    #Preview(LocalBackupSettingsView.Stance.recoveryKeySheet.title) {
        LocalBackupSettingsView.Stance.recoveryKeySheet.view
    }

    extension LocalBackupSettingsView {
        enum Stance: PreviewCase {
            case generatedKey
            case defaultKey
            case generatedKeyIncludeMediaOff
            case defaultKeyIncludeMediaOff
            case space
            case recoveryKeySheet

            var title: String {
                switch self {
                case .generatedKey: "Backup Settings - Generated Key"
                case .defaultKey: "Backup Settings - Default Key"
                case .generatedKeyIncludeMediaOff: "Backup Settings - Generated Key - Media Off"
                case .defaultKeyIncludeMediaOff: "Backup Settings - Default Key - Media Off"
                case .space: "Backup Settings - Alert Not enough space"
                case .recoveryKeySheet: "Backup Settings - Recovery Key Sheet"
                }
            }

            @MainActor
            private func makeSettings(key: BackupEncryptionKey) -> some View {
                PushedPreview {
                    LocalBackupSettingsView(
                        model: LocalBackupSettingsViewModel(
                            manager: BackupCreateManagerMock(currentRecoveryKey: key)
                        )
                    )
                }
            }

            @MainActor
            private func makeRecoveryKeySheet(
                key: BackupEncryptionKey,
                sizing: SheetPreviewSizing
            ) -> some View {
                let model = LocalBackupRecoveryKeySheetViewModel(
                    manager: BackupCreateManagerMock(currentRecoveryKey: key)
                )
                model.onContentHeightChange = { sizing.height = $0 }

                return LocalBackupRecoveryKeySheetView(model: model)
            }

            @MainActor var view: some View {
                switch self {
                case .generatedKey:
                    makeSettings(key: .mockGeneratedKey)

                case .defaultKey:
                    makeSettings(key: .mockDefaultKey)

                case .recoveryKeySheet:
                    ContentSizedSheetPreview { sizing in
                        makeRecoveryKeySheet(key: .mockDefaultKey, sizing: sizing)
                    } over: {
                        makeSettings(key: .mockDefaultKey)
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
