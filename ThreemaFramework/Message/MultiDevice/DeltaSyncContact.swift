import CocoaLumberjackSwift
import Foundation
import ThreemaProtocols

struct DeltaSyncContact: Codable {
    init(syncContact: Sync_Contact = Sync_Contact(), syncAction: SyncAction = .update) {
        self.syncContact = syncContact
        self.syncAction = syncAction
    }

    enum SyncAction: Codable {
        case create, update
    }

    var syncContact: Sync_Contact
    var syncAction: SyncAction
    var profilePicture: DeltaUpdateType = .unchanged
    var image: Data?
    var contactProfilePicture: DeltaUpdateType = .unchanged
    var contactImage: Data?
    var contactImageBlobID: Data?
    var contactImageEncryptionKey: Data?

    /// Last update of the associated conversation if there is any
    var lastConversationUpdate: Date?

    private enum CodingKeys: String, CodingKey {
        case syncContact
        case syncAction
        case profilePicture
        case image
        case contactProfilePicture
        case contactImage
        case contactImageBlobID
        case contactImageEncryptionKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let dataSyncContact = try container.decode(Data.self, forKey: .syncContact)

        self.syncContact = try Sync_Contact(contiguousBytes: dataSyncContact)
        self.syncAction = try container.decode(SyncAction.self, forKey: .syncAction)
        self.profilePicture = try container.decode(DeltaUpdateType.self, forKey: .profilePicture)
        self.image = try? container.decode(Data.self, forKey: .image)
        self.contactProfilePicture = try container.decode(DeltaUpdateType.self, forKey: .contactProfilePicture)
        self.contactImage = try? container.decode(Data.self, forKey: .contactImage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let dataSyncContact = try syncContact.serializedData()

        try container.encode(dataSyncContact, forKey: .syncContact)
        try container.encode(syncAction, forKey: .syncAction)
        try container.encode(profilePicture, forKey: .profilePicture)
        try container.encode(image, forKey: .image)
        try container.encode(contactProfilePicture, forKey: .contactProfilePicture)
        try container.encode(contactImage, forKey: .contactImage)
        try container.encode(contactImageBlobID, forKey: .contactImageBlobID)
        try container.encode(contactImageEncryptionKey, forKey: .contactImageEncryptionKey)
    }
}
