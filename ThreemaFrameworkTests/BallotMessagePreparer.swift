import CoreData
import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class BallotMessagePreparer: NSObject, ResourceLoaderProtocol {
    let testDatabase = TestDatabase()

    let groupID: Data = BytesUtility.generateGroupID()
    let myIdentity = "TESTERID"

    func prepareDatabase() {
        let databasePreparer = testDatabase.preparer
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: Data([1]),
                identity: "ECHOECHO"
            )

            _ = databasePreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.groupID = self.groupID
                    conversation.groupMyIdentity = self.myIdentity
                    conversation.contact = contact
                    conversation.groupName = "TestGroup BallotMessageDecoder"
                    conversation.members?.insert(contact)
                }
        }
    }
    
    func loadContentAsString(_ fileName: String, fileExtension: String) -> String? {
        ResourceLoader.contentAsString(fileName, fileExtension)
    }
}
