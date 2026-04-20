import Foundation
import ThreemaFramework

final class DistributionListManagerMock: NSObject, DistributionListManagerProtocol {
    func createDistributionList(
        conversation: ConversationEntity,
        name: String,
        imageData: Data?,
        recipients: Set<Contact>
    ) -> DistributionList? {
        nil
    }
    
    func distributionList(for conversation: ConversationEntity) -> DistributionList? {
        nil
    }

    func setProfilePicture(of distributionList: ThreemaFramework.DistributionList, to profilePicture: Data?) {
        // No-op
    }
    
    func setName(of distributionList: ThreemaFramework.DistributionList, to name: String) {
        // No-op
    }
    
    func setRecipients(of distributionList: ThreemaFramework.DistributionList, to recipients: Set<Contact>) {
        // No-op
    }
}
