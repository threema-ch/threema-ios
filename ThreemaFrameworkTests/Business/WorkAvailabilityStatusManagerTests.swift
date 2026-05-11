import Foundation
import Testing
@testable import ThreemaFramework

@Suite("WorkAvailabilityStatusManager Tests")
struct WorkAvailabilityStatusManagerTests {
    
    // MARK: - Helper
    
    func createManager() -> WorkAvailabilityStatusManager {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return WorkAvailabilityStatusManager(defaults: defaults)
    }
    
    // MARK: - Basic Persistence Tests (Parameterized)
    
    @Test(
        "Setting and retrieving status with description",
        arguments: [
            (category: WorkAvailabilityStatus.Category.none, text: nil),
            (category: WorkAvailabilityStatus.Category.unavailable, text: "On vacation"),
            (category: WorkAvailabilityStatus.Category.busy, text: "Working from home"),
        ]
    )
    func setAndGetStatusWithDescription(category: WorkAvailabilityStatus.Category, text: String?) {
        let manager = createManager()
        let status = WorkAvailabilityStatus(category: category, text: text)
        
        manager.setOwnStatus(status)
        let retrieved = manager.ownStatus()
        
        #expect(retrieved.category == category)
        #expect(retrieved.text == text)
    }
    
    @Test(
        "Setting and retrieving status without description",
        arguments: [
            WorkAvailabilityStatus.Category.busy,
            WorkAvailabilityStatus.Category.unavailable,
        ]
    )
    func setAndGetStatusWithoutDescription(category: WorkAvailabilityStatus.Category) {
        let manager = createManager()
        let status = WorkAvailabilityStatus(category: category, text: nil)
        
        manager.setOwnStatus(status)
        let retrieved = manager.ownStatus()
        
        #expect(retrieved.category == category)
        #expect(retrieved.text == nil)
    }
    
    @Test("Setting none removes all data")
    func settingNoneRemovesData() {
        let manager = createManager()
        
        // First set a status with description
        let initialStatus = WorkAvailabilityStatus(category: .busy, text: "In a meeting")
        manager.setOwnStatus(initialStatus)
        
        // Verify it was set
        var retrieved = manager.ownStatus()
        #expect(retrieved.category == .busy)
        #expect(retrieved.text == "In a meeting")
        
        // Set to none
        let noneStatus = WorkAvailabilityStatus(category: .none, text: nil)
        manager.setOwnStatus(noneStatus)
        
        // Verify everything is cleared
        retrieved = manager.ownStatus()
        #expect(retrieved.category == .none)
        #expect(retrieved.text == nil)
    }
    
    @Test(
        "Updating status removes old description if new has none",
        arguments: [
            (
                oldCategory: WorkAvailabilityStatus.Category.busy,
                newCategory: WorkAvailabilityStatus.Category.unavailable
            ),
            (
                oldCategory: WorkAvailabilityStatus.Category.unavailable,
                newCategory: WorkAvailabilityStatus.Category.busy
            ),
        ]
    )
    func updatingStatusRemovesOldDescription(
        oldCategory: WorkAvailabilityStatus.Category,
        newCategory: WorkAvailabilityStatus.Category
    ) {
        let manager = createManager()
        
        // Set initial status with description
        let initialStatus = WorkAvailabilityStatus(category: oldCategory, text: "Old description")
        manager.setOwnStatus(initialStatus)
        
        // Update to new status without description
        let newStatus = WorkAvailabilityStatus(category: newCategory, text: nil)
        manager.setOwnStatus(newStatus)
        
        // Verify description was removed
        let retrieved = manager.ownStatus()
        #expect(retrieved.category == newCategory)
        #expect(retrieved.text == nil)
    }
    
    // MARK: - Edge Cases
    
    @Test("Default status is none when nothing stored")
    func defaultStatusIsNone() {
        let manager = createManager()
        
        let status = manager.ownStatus()
        
        #expect(status.category == .none)
        #expect(status.text == nil)
    }
    
    @Test("Invalid category raw value defaults to none")
    func invalidCategoryDefaultsToNone() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let manager = WorkAvailabilityStatusManager(defaults: defaults)
        
        // Manually set an invalid raw value in UserDefaults
        defaults.set(9999, forKey: "WorkAvailabilityStatusCCategoryKey")
        
        let status = manager.ownStatus()
        
        #expect(status.category == .none)
        #expect(status.text == nil)
    }
    
    @Test("Multiple updates preserve latest status")
    func multipleUpdatesPreserveLatest() {
        let manager = createManager()
        
        // Set multiple statuses in sequence
        manager.setOwnStatus(WorkAvailabilityStatus(category: .busy, text: "First"))
        manager.setOwnStatus(WorkAvailabilityStatus(category: .unavailable, text: "Second"))
        manager.setOwnStatus(WorkAvailabilityStatus(category: .busy, text: "Third"))
        
        let retrieved = manager.ownStatus()
        
        #expect(retrieved.category == .busy)
        #expect(retrieved.text == "Third")
    }
    
    // MARK: - Notification Tests
    
    @Test("Notification posted when status is set")
    func notificationPostedOnSet() async throws {
        let manager = createManager()
        
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name.ownWorkAvailabilityStatusChangedName,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        
        manager.setOwnStatus(WorkAvailabilityStatus(category: .busy, text: "Test"))
        
        // Give notification time to be posted
        await Task.yield()
        
        #expect(notificationReceived)
    }
    
    @Test("Notification posted when status is removed")
    func notificationPostedOnRemove() async throws {
        let manager = createManager()
        
        // First set a status
        manager.setOwnStatus(WorkAvailabilityStatus(category: .busy, text: "Test"))
        
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name.ownWorkAvailabilityStatusChangedName,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        
        // Remove it by setting to none
        manager.setOwnStatus(WorkAvailabilityStatus(category: .none, text: nil))
        
        // Give notification time to be posted
        await Task.yield()
        
        #expect(notificationReceived)
    }
    
    @Test(
        "Notification posted for each status update",
        arguments: [
            WorkAvailabilityStatus.Category.busy,
            WorkAvailabilityStatus.Category.unavailable,
            WorkAvailabilityStatus.Category.none,
        ]
    )
    func notificationPostedForEachUpdate(category: WorkAvailabilityStatus.Category) async throws {
        let manager = createManager()
        
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name.ownWorkAvailabilityStatusChangedName,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        
        manager.setOwnStatus(WorkAvailabilityStatus(category: category, text: "Test"))
        
        // Give notification time to be posted
        await Task.yield()
        
        #expect(notificationReceived)
    }
    
    // MARK: - Description Edge Cases
    
    @Test(
        "Empty string and nil description handling",
        arguments: [
            "",
            nil,
        ]
    )
    func emptyStringAndNilDescription(text: String?) {
        let manager = createManager()
        let status = WorkAvailabilityStatus(category: .busy, text: text)
        
        manager.setOwnStatus(status)
        let retrieved = manager.ownStatus()
        
        #expect(retrieved.category == .busy)
        #expect(retrieved.text == nil)
    }
}
