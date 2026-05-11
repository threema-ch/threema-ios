import CocoaLumberjackSwift
import Foundation
import ThreemaMacros

@MainActor
@Observable
final class WorkAvailabilityStatusViewModel {

    // MARK: - Public Properties

    let onDismiss: (() -> Void)?

    let navigationTitle = #localize("work_availability_status_title")
    let companyInfo = #localize("work_availability_status_company_info")
    let textFieldPlaceholder = #localize("work_availability_status_text_placeholder")
    let textFieldSectionHeader = #localize("work_availability_status_text_header")
    let textFieldSectionFooter = #localize("work_availability_status_text_footer")
    let textConfirmationButton = #localize("save")
    let textLimitExceededMessage = #localize("work_availability_status_text_limit_exceeded_message")
    let profileStore: any ProfileStoreProtocol

    let statusTextByteLimit = 256

    /// We need to calculate the status length in bytes since the max limit is in bytes not in characters.
    /// "a" → 1 byte
    /// "é" → 2 bytes
    /// "你" → 3 bytes
    /// "😀" → 4 bytes
    var isByteLimitExceeded: Bool {
        statusText.utf8.count > statusTextByteLimit
    }
    
    var statusChanged: Bool {
        currentStatus?.category != selectedStatus || currentStatus?.text != statusText
    }

    var isLoading = false

    var statusText = ""

    var selectedStatus: WorkAvailabilityStatus.Category = .none

    private var currentStatus: WorkAvailabilityStatus?

    // MARK: - Lifecycle
    
    init(profileStore: any ProfileStoreProtocol, onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        self.profileStore = profileStore
    }
    
    func loadCurrentStatus() {
        guard let status = profileStore.profile.workAvailabilityStatus else {
            currentStatus = nil
            return
        }
        
        currentStatus = status
        selectedStatus = status.category
        statusText = status.text ?? ""
    }

    func cancelButtonTapped() {
        onDismiss?()
    }

    func confirmationButtonTapped() async {
        do {
            isLoading = true
            try await save()
            onDismiss?()
        }
        catch {
            DDLogError("Failed to save work availability status: \(error)")
            NotificationPresenterWrapper.shared.present(type: .setWorkAvailabilityStatusFailed)
        }
    }

    // MARK: - Private methods

    private func save() async throws {
        let trimmed = statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        let text: String? = trimmed.isEmpty ? nil : statusText
        let status = WorkAvailabilityStatus(category: selectedStatus, text: text)
        try await profileStore.syncAndSave(workAvailabilityStatus: status)
    }
}
