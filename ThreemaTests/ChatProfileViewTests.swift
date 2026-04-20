import ThreemaEssentials
import XCTest
@testable import Threema
@testable import ThreemaFramework

final class ChatProfileViewTests: XCTestCase {
    
    private var testDatabase: TestDatabase!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        testDatabase = TestDatabase()
    }
    
    /// Wait for main thread to complete UI updates
    private func waitForMainThread() {
        let mainThreadExpectation = expectation(description: "mainThread")
        DispatchQueue.main.async {
            mainThreadExpectation.fulfill()
        }
        
        wait(for: [mainThreadExpectation], timeout: 2)
    }
    
    // MARK: - Chats
    
    private func createConversation() -> (ContactEntity, ConversationEntity) {
        var contact: ContactEntity!
        var conversation: ConversationEntity!
        
        let databasePreparer = testDatabase.preparer
        databasePreparer.save {
            contact = databasePreparer.createContact(publicKey: Data([1]), identity: "ECHOECHO")
            
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { conversation in
                conversation.contact = contact
            }
        }
        
        return (contact, conversation)
    }

    func testBasicInitialization() throws {
        let (contact, conversation) = createConversation()
        let businessContact = Contact(contactEntity: contact)
        contact.setFirstName(to: "Emily", sortOrderFirstName: true)

        let expectedAccessibilityLabel =
            "\(contact.displayName). \(businessContact.verificationLevelAccessibilityLabel)"

        let chatProfileView = ChatProfileView(
            for: conversation,
            entityManager: testDatabase.entityManager,
            initialUnreadCount: 0,
            isRegularSizeClass: { false }
        ) {
            // no-op
        }
        
        waitForMainThread()
        
        XCTAssertEqual(chatProfileView.accessibilityLabel, expectedAccessibilityLabel)
    }
    
    func testObserveNameChange() throws {
        let (contact, conversation) = createConversation()
        let businessContact = Contact(contactEntity: contact)

        let chatProfileView = ChatProfileView(
            for: conversation,
            entityManager: testDatabase.entityManager,
            initialUnreadCount: 0,
            isRegularSizeClass: { false }
        ) {
            // no-op
        }
        
        conversation.contact!.setFirstName(to: "Emily", sortOrderFirstName: true)
        let expectedAccessibilityLabel =
            "\(contact.displayName). \(businessContact.verificationLevelAccessibilityLabel)"
        
        waitForMainThread()
        
        XCTAssertEqual(chatProfileView.accessibilityLabel, expectedAccessibilityLabel)
    }
    
    func testObserveVerificationLevelChange() throws {
        let (contact, conversation) = createConversation()
        let businessContact = Contact(contactEntity: contact)

        let chatProfileView = ChatProfileView(
            for: conversation,
            entityManager: testDatabase.entityManager,
            initialUnreadCount: 0,
            isRegularSizeClass: { false }
        ) {
            // no-op
        }
        
        contact.contactVerificationLevel = .fullyVerified
        let expectedAccessibilityLabel =
            "\(contact.displayName). \(businessContact.verificationLevelAccessibilityLabel)"
        
        waitForMainThread()
        
        XCTAssertEqual(chatProfileView.accessibilityLabel, expectedAccessibilityLabel)
    }
    
    // MARK: - Group chats
    
    private func createGroupConversation() -> ConversationEntity {
        var conversation: ConversationEntity!
        
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupName = "Foodies"
        let memberNames = ["MEMBER01", "MEMBER02", "MEMBER03"]
        let databasePreparer = testDatabase.preparer

        let members = memberNames.map { name -> ContactEntity in
            databasePreparer.createContact(publicKey: Data([1]), identity: name, verificationLevel: .serverVerified)
        }
        
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { conversation in
                // Needed such that `conversation.isGroup()` returns true
                conversation.groupID = groupID
                
                conversation.groupName = groupName
                conversation.members = Set(members)
            }
        }
        
        return conversation
    }
    
    func testObserveGroupNameChange() throws {
        let groupName = "Group1"
        
        let conversation = createGroupConversation()
        let chatProfileView = ChatProfileView(
            for: conversation,
            entityManager: testDatabase.entityManager,
            initialUnreadCount: 0,
            isRegularSizeClass: { false }
        ) {
            // no-op
        }
        
        conversation.groupName = groupName
        
        waitForMainThread()
        
        XCTAssertEqual(chatProfileView.accessibilityLabel, groupName)
    }
    
    func testObserveMembersChange() throws {
        let conversation = createGroupConversation()
        _ = ChatProfileView(
            for: conversation,
            entityManager: testDatabase.entityManager,
            initialUnreadCount: 0,
            isRegularSizeClass: { false }
        ) {
            // no-op
        }
        
        conversation.members?.removeFirst()
        
        // As the members list label is private we cannot assert anything.
        // This test just checks if there are any crashes due to the observers.
    }
    
    func testObserveMemberNameChange() throws {
        let conversation = createGroupConversation()
        _ = ChatProfileView(
            for: conversation,
            entityManager: testDatabase.entityManager,
            initialUnreadCount: 0,
            isRegularSizeClass: { false }
        ) {
            // no-op
        }
        
        let contact = try XCTUnwrap(conversation.members?.first)
        contact.setLastName(to: "1stMember", sortOrderFirstName: true)

        // As the members list label is private we cannot assert anything.
        // This test just checks if there are any crashes due to the observers.
    }
    
    func testDoNotObserveRemovedMemberNameChange() throws {
        let conversation = createGroupConversation()
        _ = ChatProfileView(
            for: conversation,
            entityManager: testDatabase.entityManager,
            initialUnreadCount: 0,
            isRegularSizeClass: { false }
        ) {
            // no-op
        }
        
        let contact = try XCTUnwrap(conversation.members?.removeFirst())
        contact.setLastName(to: "1stRemovedMember", sortOrderFirstName: true)

        // As the members list label is private we cannot assert anything.
        // This test just checks if there are any crashes due to the observers.
    }
}
