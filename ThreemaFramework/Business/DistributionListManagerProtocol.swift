import Foundation

public protocol DistributionListManagerProtocol {
    // MARK: - General

    func createDistributionList(
        conversation: ConversationEntity,
        name: String,
        imageData: Data?,
        recipients: Set<Contact>
    ) -> DistributionList?
    
    func distributionList(for conversation: ConversationEntity) -> DistributionList?
    
    // MARK: - Update

    func setProfilePicture(of distributionList: DistributionList, to profilePicture: Data?)
    func setName(of distributionList: DistributionList, to name: String)
    func setRecipients(of distributionList: DistributionList, to recipients: Set<Contact>)
}
