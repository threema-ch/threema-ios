import Foundation
import ThreemaFramework

final class MessageRetentionManagerModelMock: MessageRetentionManagerModelProtocol {
    var selection = 0
    
    var isMDM = false
    
    func deleteOldMessages() async { }
    
    func numberOfMessagesToDelete(for retentionDays: Int?) async -> Int {
        0
    }
    
    func set(_ days: Int, completion: (() -> Void)?) {
        selection = days
        completion?()
    }
}
