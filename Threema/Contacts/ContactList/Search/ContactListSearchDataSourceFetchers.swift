import CoreData
import ThreemaEssentials

struct ContactListSearchDataSourceFetchers {
    let fetchContact: (NSManagedObjectID) -> ContactEntity?
    let fetchGroup: (NSManagedObjectID) -> Group?
    let fetchDistributionList: (NSManagedObjectID) -> DistributionListEntity?
    let fetchContactIDsForSearch: (String) -> [(
        objectID: NSManagedObjectID,
        identity: ThreemaIdentity
    )]
    let fetchConversationsForSearch: (String) -> [NSManagedObjectID]
    let fetchDistributionListIDsForSearch: (String) -> [NSManagedObjectID]
    let fetchDirectoryCategories: () -> [String: String]?
    let fetchCompanyName: () -> String?
    let isCompanyDirectory: () -> Bool
    let isBusinessApp: () -> Bool
    
    init(
        fetchContact: @escaping (NSManagedObjectID) -> ContactEntity?,
        fetchGroup: @escaping (NSManagedObjectID) -> Group?,
        fetchDistributionList: @escaping (NSManagedObjectID) -> DistributionListEntity?,
        fetchContactIDsForSearch: @escaping (String) -> [(NSManagedObjectID, ThreemaIdentity)],
        fetchConversationsForSearch: @escaping (String) -> [NSManagedObjectID],
        fetchDistributionListIDsForSearch: @escaping (String) -> [NSManagedObjectID],
        fetchDirectoryCategories: @autoclosure @escaping () -> [String: String]?,
        fetchCompanyName: @autoclosure @escaping () -> String?,
        isCompanyDirectory: @autoclosure @escaping () -> Bool,
        isBusinessApp: @autoclosure @escaping () -> Bool
    ) {
        self.fetchContact = fetchContact
        self.fetchGroup = fetchGroup
        self.fetchDistributionList = fetchDistributionList
        self.fetchContactIDsForSearch = fetchContactIDsForSearch
        self.fetchConversationsForSearch = fetchConversationsForSearch
        self.fetchDistributionListIDsForSearch = fetchDistributionListIDsForSearch
        self.fetchDirectoryCategories = fetchDirectoryCategories
        self.fetchCompanyName = fetchCompanyName
        self.isCompanyDirectory = isCompanyDirectory
        self.isBusinessApp = isBusinessApp
    }
}
