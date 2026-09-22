import Testing
import ThreemaEssentials
@testable import ThreemaFramework

@Suite
struct SpamDetectorTests {
    
    private let testDatabase = TestDatabase()
    
    @Test func `1: No associated contact is not spam`() async throws {
        let conversation = createConversation(identity: nil)
        let spamDetector = createSpamDetector()
        
        #expect(await spamDetector.isPotentialSpam(conversationObjectID: conversation.objectID) == false)
    }
    
    @Test func `2: Verified contact is not spam`() async throws {
        let conversation = createConversation(verificationLevel: .serverVerified)
        let spamDetector = createSpamDetector()
        
        #expect(await spamDetector.isPotentialSpam(conversationObjectID: conversation.objectID) == false)
    }
    
    @Test func `3: A conversation with an outgoing _content_ message is not spam`() async throws {
        let conversation = createConversation()
        
        testDatabase.preparer.save {
            testDatabase.preparer.createTextMessage(
                conversation: conversation,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
        }
        
        let spamDetector = createSpamDetector()
        
        #expect(await spamDetector.isPotentialSpam(conversationObjectID: conversation.objectID) == false)
    }
    
    @Test func `4: A conversation with no messages is not spam`() async throws {
        let conversation = createConversation()
        let spamDetector = createSpamDetector()
        
        #expect(await spamDetector.isPotentialSpam(conversationObjectID: conversation.objectID) == false)
    }
    
    @Test func `4: A conversation with just _event_ messages is not spam`() async throws {
        let conversation = createConversation()
        
        testDatabase.preparer.save {
            testDatabase.preparer.createSystemMessage(conversation: conversation, type: .fsSessionEstablished)
        }
        
        let spamDetector = createSpamDetector()
        
        #expect(await spamDetector.isPotentialSpam(conversationObjectID: conversation.objectID) == false)
    }
    
    @Test func `5: If the earliest message is more than 7 days older than the contact creation date it is not spam`() async throws {
        let conversation = createConversation(contactCreationDate: .now.addingTimeInterval(-(24 * 60 * 60 * 7 + 1)))
        
        testDatabase.preparer.save {
            testDatabase.preparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: nil, // Not really correct but not relevant for this test
                remoteSentDate: .now
            )
        }
        
        let spamDetector = createSpamDetector()
        
        #expect(await spamDetector.isPotentialSpam(conversationObjectID: conversation.objectID) == false)
    }
    
    @Test func `7: If there there are only incoming messages in the 7 days the contact was created in it might be spam`(
    ) async throws {
        let conversation = createConversation()
        
        testDatabase.preparer.save {
            testDatabase.preparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: nil, // Not really correct but not relevant for this test
                remoteSentDate: .now
            )
        }
        
        let spamDetector = createSpamDetector()
        
        #expect(await spamDetector.isPotentialSpam(conversationObjectID: conversation.objectID) == true)
    }
    
    @Test
    func `4, 5 & 6: If there there are only incoming messages where at least one is in 7 days as the contact was created it might be spam`(
    ) async throws {
        let conversation = createConversation(contactCreationDate: .now.addingTimeInterval(-(24 * 60 * 60 * 8)))
        
        testDatabase.preparer.save {
            let callEndedOutgoingSystemMessage = testDatabase.preparer.createSystemMessage(
                conversation: conversation,
                type: .callEnded,
                date: .now.addingTimeInterval(-(20 * 60 * 60 * 7))
            )
            callEndedOutgoingSystemMessage.isOwn = false

            testDatabase.preparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: nil, // Not really correct but not relevant for this test
                remoteSentDate: .now
            )
        }
        
        let spamDetector = createSpamDetector()
        
        #expect(await spamDetector.isPotentialSpam(conversationObjectID: conversation.objectID) == true)
    }
    
    // MARK: - Helper
    
    private func createConversation(
        identity: String? = "ABCDEFGH",
        verificationLevel: ContactEntity.VerificationLevel = .unverified,
        contactCreationDate: Date = .now
    ) -> ConversationEntity {
        testDatabase.preparer.save {
            guard let identity else {
                return testDatabase.preparer.createConversation()
            }
            
            let contact = testDatabase.preparer.createContact(identity: identity, createdAt: contactCreationDate)
            contact.contactVerificationLevel = verificationLevel
            
            return testDatabase.preparer.createConversation(contactEntity: contact)
        }
    }
    
    private func createSpamDetector() -> SpamDetector {
        // The spam detection must run on a background (private queue) Core Data context
        let businessInjectorMock = BusinessInjectorMock(entityManager: testDatabase.backgroundEntityManager)
        
        return SpamDetector(businessInjector: businessInjectorMock)
    }
}
