import Foundation
import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class MessageDraftStoreTests: XCTestCase {
    private var testDatabase: TestDatabase!

    var testConversation: ConversationEntity!
    var testDraft: Draft!
    var draftStore: MessageDraftStore!

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
    
    override func setUpWithError() throws {
        super.setUp()
        AppGroup.setGroupID("group.ch.threema")

        testDatabase = TestDatabase()

        (_, testConversation) = createConversation()
        draftStore = MessageDraftStore()
        testDraft = Draft(key: .messageDrafts, value: "hello world")
    }

    override func tearDownWithError() throws {
        draftStore.deleteDraft(for: testConversation)
        super.tearDown()
    }

    func testSaveDraft() {
        draftStore.saveDraft(testDraft, for: testConversation)
        let loadedDraft = draftStore.loadDraft(for: testConversation)
        XCTAssertNotNil(loadedDraft, "Draft should be saved and loaded successfully")
        XCTAssertEqual(loadedDraft?.string, testDraft.string, "Loaded draft message should match the saved message")
    }

    func testDeleteDraft() {
        draftStore.saveDraft(testDraft, for: testConversation)
        draftStore.deleteDraft(for: testConversation)
        let loadedDraft = draftStore.loadDraft(for: testConversation)
        XCTAssertNil(loadedDraft, "Draft should be deleted successfully")
    }

    func testLoadDraft() {
        // Ensure no draft initially
        XCTAssertNil(draftStore.loadDraft(for: testConversation), "No draft should be loaded initially")
        // Save and load to test
        draftStore.saveDraft(testDraft, for: testConversation)
        let loadedDraft = draftStore.loadDraft(for: testConversation)
        XCTAssertNotNil(loadedDraft, "Draft should be loaded successfully")
    }

    func testPreviewForDraft() {
        draftStore.saveDraft(testDraft, for: testConversation)
        let preview = draftStore.previewForDraft(for: testConversation, textStyle: .body, tint: .blue)
        XCTAssertNotNil(preview, "Preview should be generated for existing draft")
        XCTAssertEqual(preview?.string, testDraft.string, "Preview text should match draft message")
    }
}
