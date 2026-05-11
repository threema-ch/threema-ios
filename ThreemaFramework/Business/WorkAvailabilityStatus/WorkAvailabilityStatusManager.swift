import CocoaLumberjackSwift
import Foundation

public class WorkAvailabilityStatusManager: WorkAvailabilityStatusManagerProtocol {
    
    private let workAvailabilityStatusCategoryKey = "WorkAvailabilityStatusCategoryKey"
    private let workAvailabilityStatusTextKey = "workAvailabilityStatusTextKey"

    private let defaults: UserDefaults
    
    // MARK: - Lifecycle
    
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }
    
    // MARK: - Own Status
    
    public func ownStatus() -> WorkAvailabilityStatus {
        let categoryRawValue = defaults.integer(forKey: workAvailabilityStatusCategoryKey)
        let text = defaults.string(forKey: workAvailabilityStatusTextKey)
        
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
        
        defaults.set(status.category.rawValue, forKey: workAvailabilityStatusCategoryKey)
        
        // We make sure the text gets removed if no text is set for new status
        if let text = status.text, !text.isEmpty {
            defaults.set(text, forKey: workAvailabilityStatusTextKey)
        }
        else {
            defaults.removeObject(forKey: workAvailabilityStatusTextKey)
        }
    }
    
    private func removeOwnStatus() {
        defaults.removeObject(forKey: workAvailabilityStatusCategoryKey)
        defaults.removeObject(forKey: workAvailabilityStatusTextKey)
        DDLogNotice("[WorkAvailabilityStatusManager] Removed own status.")
    }
}
