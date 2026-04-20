import Foundation

public protocol MessageRetentionManagerModelProtocol {
    var selection: Int { get set }
    var isMDM: Bool { get }
    func deleteOldMessages() async
    func numberOfMessagesToDelete(for retentionDays: Int?) async -> Int
    func set(_ days: Int, completion: (() -> Void)?)
}

extension MessageRetentionManagerModelProtocol {
    func deletionDate(_ days: Int) -> Date? {
        Calendar.current.date(byAdding: .day, value: -days, to: Date.currentDate)
    }
}
