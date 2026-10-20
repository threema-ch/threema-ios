import DataBackup
import Observation
import ThreemaFramework
import ThreemaMacros

@MainActor
@Observable
final class LocalBackupSettingsViewModel {

    // MARK: - Public types

    struct MediaItem: Identifiable, Hashable {
        let iconName: String
        let title: String
        let subtitle: String

        var id: String { iconName }
    }

    // MARK: Public properties

    let checkmarkIconName = "checkmark.circle.fill"
    let disclosureIconName = "chevron.right"
    let includedMessagesSubtitle = #localize("backup_local_settings_messages_description")
    let includedMessagesTitle = #localize("messages")
    let includedSectionFooter = #localize("backup_local_settings_included_section_footer")
    let includedSectionHeader = #localize("backup_local_settings_included_section_header")
    let includeMediaSubtitle = #localize("backup_local_settings_included_media_subtitle")
    let includeMediaTitle = #localize("backup_local_settings_include_media_title")
    let mediaSectionFooter = #localize("backup_local_settings_media_section_footer")
    let mediaSectionHeader = #localize("media")
    let recoveryKeyLabel = #localize("Recovery_Key")
    let recoveryKeySectionHeader = #localize("encrypting_with")
    let headerIconName = "gearshape"

    @ObservationIgnored var onStartButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onRecoveryKeyDetailsButtonTapped: () -> Void = { /* no-op */ }

    private let manager: any BackupCreateManagerProtocol

    var headerTitle: String {
        if isDefaultKey {
            #localize("confirm_settings")
        }
        else {
            #localize("backup_settings")
        }
    }

    var headerSubtitle: String {
        if isDefaultKey {
            #localize("backup_local_settings_reuse_description")
        }
        else {
            #localize("backup_local_settings_description")
        }
    }

    var stepLabel: String {
        let currentStep = isDefaultKey ? 1 : 2
        let totalSteps = isDefaultKey ? 2 : 3
        return String.localizedStringWithFormat(
            #localize("step_count_from_total_steps"), currentStep, totalSteps
        ).uppercased()
    }

    var isDefaultKey: Bool {
        manager.currentRecoveryKey.isDefault
    }

    var recoveryKeyTrimmed: String {
        manager.currentRecoveryKey.trimmedValue
    }

    let mediaItems: [MediaItem] = [
        MediaItem(
            iconName: "photo",
            title: #localize("photos"),
            subtitle: #localize("backup_local_settings_included_photos_description")
        ),
        MediaItem(
            iconName: "video.fill",
            title: #localize("videos"),
            subtitle: #localize("backup_local_settings_included_videos_description")
        ),
        MediaItem(
            iconName: "document.fill",
            title: #localize("documents_and_files"),
            subtitle: #localize("backup_local_settings_included_documents_description")
        ),
        MediaItem(
            iconName: "waveform.circle.fill",
            title: #localize("voice_messages"),
            subtitle: #localize("backup_local_settings_voice_messages")
        ),
    ]

    let startButtonTitle = #localize("backup_local_settings_start_button_title")

    let notEnoughStorageTitle = #localize("not_enough_storage")

    // TODO: Hardcoded values
    let notEnoughStorageMessage = String.localizedStringWithFormat(
        #localize("backup_creation_not_enough_storage_details"), "1.2 GB", "0.4 GB"
    )

    let freeUpSpaceButtonTitle = #localize("free_up_space")
    let excludeMediaButtonTitle = #localize("exclude_media")
    let cancelButtonTitle = #localize("cancel")

    var includeMedia: Bool {
        didSet {
            manager.backupSettings.includesMedia = includeMedia
        }
    }

    var showNotEnoughStorageAlert = false

    // Lifecycle

    init(manager: any BackupCreateManagerProtocol) {
        self.manager = manager
        self.includeMedia = manager.backupSettings.includesMedia
    }

    // MARK: Public methods

    func startButtonTapped() {
        onStartButtonTapped()

        // TODO: Replace with a real available-storage check.
    }

    func freeUpSpaceTapped() {
        // TODO: Route the user to free up device storage.
    }

    func excludeMediaTapped() {
        includeMedia = false
        showNotEnoughStorageAlert = false
    }

    func cancelButtonTapped() {
        // TODO: - Add implementation
        showNotEnoughStorageAlert = false
    }

    func recoveryKeyDetailsButtonTapped() {
        onRecoveryKeyDetailsButtonTapped()
    }
}
