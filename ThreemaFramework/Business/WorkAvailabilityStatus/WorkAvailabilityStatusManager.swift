import CocoaLumberjackSwift
import Foundation

public final class WorkAvailabilityStatusManager: WorkAvailabilityStatusManagerProtocol {
    
    static let workAvailabilityStatusCategoryKey = "WorkAvailabilityStatusCategoryKey"
    static let workAvailabilityStatusTextKey = "workAvailabilityStatusTextKey"

    private let defaults: UserDefaults
    
    // MARK: - Lifecycle
    
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }
    
    // MARK: - Own Status
    
    public func ownStatus() -> WorkAvailabilityStatus {
        let categoryRawValue = defaults.integer(forKey: Self.workAvailabilityStatusCategoryKey)
        let text = defaults.string(forKey: Self.workAvailabilityStatusTextKey)
        
        guard let category = WorkAvailabilityStatus.Category(rawValue: categoryRawValue) else {
            DDLogError(
                "[WorkAvailabilityStatusManager] Could not parse WorkAvailabilityStatus.Category from UserDefaults: Value was \(categoryRawValue)"
            )
            return WorkAvailabilityStatus(category: .none, text: nil)
        }
        
        return WorkAvailabilityStatus(category: category, text: text)
    }
    
    public func setOwnStatus(_ status: WorkAvailabilityStatus?) {
        defer {
            NotificationCenter.default.post(
                name: Notification.Name.ownWorkAvailabilityStatusChangedName,
                object: nil
            )
        }
        
        // If we get nil or we set `.none`, we remove all persisted elements
        guard let status, status.category != .none else {
            removeOwnStatus()
            return
        }
        
        defaults.set(status.category.rawValue, forKey: Self.workAvailabilityStatusCategoryKey)
        
        // We make sure the text gets removed if no text is set for new status
        if let text = status.text, !text.isEmpty {
            defaults.set(text, forKey: Self.workAvailabilityStatusTextKey)
        }
        else {
            defaults.removeObject(forKey: Self.workAvailabilityStatusTextKey)
        }
    }
    
    private func removeOwnStatus() {
        defaults.removeObject(forKey: Self.workAvailabilityStatusCategoryKey)
        defaults.removeObject(forKey: Self.workAvailabilityStatusTextKey)
        DDLogNotice("[WorkAvailabilityStatusManager] Removed own status.")
    }
}
