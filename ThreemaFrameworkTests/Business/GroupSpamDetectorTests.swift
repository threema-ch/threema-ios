import Testing
@testable import ThreemaFramework

@Suite
struct GroupSpamDetectorTests {
    
    private let testDatabase = TestDatabase()
    
    init() {
        AppGroup.setGroupID("group.ch.threema")
    }
    
    @Test func `1: A group marked as not spam is not group spam`() async throws {
        let (conversationEntity, groupEntity) = createGroupEntities(spamReportingState: .notSpam)
        
        testDatabase.preparer.save {
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                isOwn: false,
                sender: nil, // Not really correct but not relevant for this test
                remoteSentDate: .now
            )
        }
        
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `1: A group marked as reported is not group spam`() async throws {
        let (conversationEntity, groupEntity) = createGroupEntities(spamReportingState: .reported)
        
        testDatabase.preparer.save {
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                isOwn: false,
                sender: nil, // Not really correct but not relevant for this test
                remoteSentDate: .now
            )
        }
        
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `2: A 1:1 conversation is not group spam`() async throws {
        let conversationEntity = testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: "ABCDEFGH")
            let conversationEntity = testDatabase.preparer.createConversation(contactEntity: contactEntity)
            
            testDatabase.preparer.save {
                testDatabase.preparer.createTextMessage(
                    conversation: conversationEntity,
                    isOwn: false,
                    sender: nil, // Not really correct but not relevant for this test
                    remoteSentDate: .now
                )
            }
            
            return conversationEntity
        }
        let businessInjectorMock = BusinessInjectorMock(entityManager: testDatabase.backgroundEntityManager)
        
        let groupSpamDetector = GroupSpamDetector(businessInjector: businessInjectorMock)
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `3: A group I created it not group spam`() async throws {
        let myIdentityStoreMock = createMyIdentityStoreMock()
        let (conversationEntity, groupEntity) = createGroupEntities(myIdentityStoreMock: myIdentityStoreMock)
        
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity,
            myIdentityStoreMock: myIdentityStoreMock
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `3: A left group is not group spam`() async throws {
        let (conversationEntity, groupEntity) = createGroupEntities(state: .left)
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `3: A forced left group is not group spam`() async throws {
        let (conversationEntity, groupEntity) = createGroupEntities(state: .forcedLeft)
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `4: A group with a verified creator is not group spam`() async throws {
        let (conversationEntity, groupEntity) = createGroupEntities(verificationLevel: .serverVerified)
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `5: A group with an outgoing _content_ message is not group spam`() async throws {
        let (conversationEntity, groupEntity) = createGroupEntities()
        
        testDatabase.preparer.save {
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
        }
        
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `7: A group with no _content_ message is not group spam`() async throws {
        let (conversationEntity, groupEntity) = createGroupEntities()
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `7: A group with just _event_ messages is not group spam`() async throws {
        let (conversationEntity, groupEntity) = createGroupEntities()
        
        testDatabase.preparer.save {
            testDatabase.preparer.createSystemMessage(conversation: conversationEntity, type: .fsSessionEstablished)
        }
        
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `8: If the earliest _content_ message was received more than 7 days after the creators creation date it is not group spam`(
    ) async throws {
        let (conversationEntity, groupEntity) = createGroupEntities(
            creatorCreationDate: .now.addingTimeInterval(-(24 * 60 * 60 * 7 + 1))
        )
        
        testDatabase.preparer.save {
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                isOwn: false,
                sender: nil, // Not really correct but not relevant for this test
                remoteSentDate: .now
            )
        }
        
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == false)
    }
    
    @Test func `9: If there there are only incoming _content_ messages in the 7 days after the creator was created in it might be group spam`(
    ) async throws {
        let (conversationEntity, groupEntity) = createGroupEntities()
        
        testDatabase.preparer.save {
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                isOwn: false,
                sender: nil, // Not really correct but not relevant for this test
                remoteSentDate: .now
            )
        }
        
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == true)
    }
    
    @Test func `5 - 9: If there there are only incoming _content_ messages where at least one is in the 7 days after the creator was created it might be group spam`(
    ) async throws {
        let (conversationEntity, groupEntity) = createGroupEntities(
            creatorCreationDate: .now.addingTimeInterval(-(24 * 60 * 60 * 8))
        )
        
        testDatabase.preparer.save {
            let callEndedOutgoingSystemMessage = testDatabase.preparer.createSystemMessage(
                conversation: conversationEntity,
                type: .callEnded,
                date: .now.addingTimeInterval(-(20 * 60 * 60 * 7))
            )
            callEndedOutgoingSystemMessage.isOwn = false
            
            testDatabase.preparer.createTextMessage(
                conversation: conversationEntity,
                isOwn: false,
                sender: nil, // Not really correct but not relevant for this test
                remoteSentDate: .now
            )
        }
        
        let groupSpamDetector = createGroupSpamDetector(
            conversationEntity: conversationEntity,
            groupEntity: groupEntity
        )
        
        #expect(await groupSpamDetector.isPotentialSpam(conversationObjectID: conversationEntity.objectID) == true)
    }
    
    // MARK: - Helper
    
    private func createMyIdentityStoreMock() -> MyIdentityStoreMock {
        let creatorID = "ABDCEDFH"
        
        return MyIdentityStoreMock(
            identity: creatorID,
            secretKey: Data(base64Encoded: "WAXm465d3CNnP1pf84RF0mYRgV/Umqwe/8Hun9ntTdQ=")!
        )
    }
    
    private func createGroupEntities(
        myIdentityStoreMock: MyIdentityStoreMock? = nil,
        state: GroupEntity.GroupState = .active,
        spamReportingState: ConversationEntity.SpamReportingState = .open,
        verificationLevel: ContactEntity.VerificationLevel = .unverified,
        creatorCreationDate: Date = .now
    ) -> (ConversationEntity, GroupEntity) {
        let creatorID = myIdentityStoreMock?.identity ?? "ABDCEDFH"
        
        return testDatabase.preparer.save {
            let (creatorEntity, groupEntity, conversationEntity) = testDatabase.preparer.createGroup(
                groupCreatorIdentity: creatorID,
                members: ["MEMBER01", "MEMBER02"],
                myIdentityStoreMock: myIdentityStoreMock
            )
            
            creatorEntity?.contactVerificationLevel = verificationLevel
            creatorEntity?.createdAt = creatorCreationDate
            
            groupEntity.state = state.rawValue as NSNumber
            
            conversationEntity.spamReportingState = spamReportingState
            
            return (conversationEntity, groupEntity)
        }
    }
    
    private func createGroupSpamDetector(
        conversationEntity: ConversationEntity,
        groupEntity: GroupEntity,
        myIdentityStoreMock: MyIdentityStoreMock = MyIdentityStoreMock()
    ) -> GroupSpamDetector {
        let userSettingsMock = UserSettingsMock()
        let pushSettingsManagerMock = PushSettingManagerMock()
        
        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            pushSettingManager: pushSettingsManagerMock,
            groupEntity: groupEntity,
            conversation: conversationEntity,
            lastSyncRequest: nil
        )
        
        // The spam detection must run on a background (private queue) Core Data context
        let groupManagerMock = GroupManagerMock(myIdentityStoreMock)
        groupManagerMock.getGroupReturns = [group]
        
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.backgroundEntityManager,
            groupManager: groupManagerMock,
            userSettings: userSettingsMock,
            pushSettingManager: pushSettingsManagerMock
        )

        return GroupSpamDetector(businessInjector: businessInjectorMock)
    }
}
