import Testing
import ThreemaEssentials
@testable import ThreemaFramework

@Suite
struct IdentityBlockerTests {
    
    private let testDatabase = TestDatabase()

    @Test func `2: Special contacts are never blocked`() async throws {
        let specialContactIdentity = try ThreemaIdentity(identity: "*3MAPUSH")
        let identityBlocker = createIdentityBlocker(blockUnknown: false)
        
        #expect(identityBlocker.check(identity: specialContactIdentity) == .notBlocked)
    }
    
    @Test func `3: Explicit blocked identities are blocked`() async throws {
        let testIdentity = try ThreemaIdentity(identity: "ABCDEFGH")
        let identityBlocker = createIdentityBlocker(blockUnknown: false, blocklist: [testIdentity])
        
        #expect(identityBlocker.check(identity: testIdentity) == .blocked)
    }
    
    @Test func `4: If unknown contacts are not blocked an identity is not blocked unless it is explicitly blocked`() async throws {
        let testIdentity = try ThreemaIdentity(identity: "ABCDEFGH")
        
        let identityBlocker = createIdentityBlocker(blockUnknown: false)
        
        #expect(identityBlocker.check(identity: testIdentity) == .notBlocked)
    }
    
    @Test func `5: If unknown contacts are blocked predefined contacts are not blocked`() async throws {
        let predefinedContactIdentity = try ThreemaIdentity(identity: "*THREEMA")
        
        let identityBlocker = createIdentityBlocker(blockUnknown: true)
        
        #expect(identityBlocker.check(identity: predefinedContactIdentity) == .notBlocked)
    }
    
    @Test func `7: If unknown contacts are blocked and the contact doesn't exist in Core Data it is blocked`() async throws {
        let testIdentity = try ThreemaIdentity(identity: "ABCDEFGH")
        let identityBlocker = createIdentityBlocker(blockUnknown: true)
        
        #expect(identityBlocker.check(identity: testIdentity) == .blocked)
    }
    
    @Test func `8: If unknown contacts are blocked and the contact is not hidden it is not blocked`() async throws {
        let testIdentity = try ThreemaIdentity(identity: "ABCDEFGH")
        
        let contactEntity = testDatabase.preparer.createContact(identity: testIdentity.rawValue)
        contactEntity.isHidden = false
        
        let identityBlocker = createIdentityBlocker(blockUnknown: true)
        
        #expect(identityBlocker.check(identity: testIdentity) == .notBlocked)
    }
    
    @Test func `9: If unknown contacts are blocked and the contact is hidden but part of an not left group is it not blocked`(
    ) async throws {
        let testGroupCreateIdentity = try ThreemaIdentity(identity: "CREATOR0")
        let testIdentity = try ThreemaIdentity(identity: "ABCDEFGH")
        
        let contactEntity = testDatabase.preparer.createContact(identity: testIdentity.rawValue)
        contactEntity.isHidden = true
        
        testDatabase.preparer.createGroup(
            groupCreatorIdentity: testGroupCreateIdentity.rawValue,
            members: [testIdentity.rawValue]
        )
        
        let identityBlocker = createIdentityBlocker(blockUnknown: true)
        
        #expect(identityBlocker.check(identity: testIdentity) == .notBlocked)
    }
    
    @Test func `10: If unknown contacts are blocked and the contact is hidden it is blocked`() async throws {
        let testIdentity = try ThreemaIdentity(identity: "ABCDEFGH")
        
        let contactEntity = testDatabase.preparer.createContact(identity: testIdentity.rawValue)
        contactEntity.isHidden = true
        
        let identityBlocker = createIdentityBlocker(blockUnknown: true)
        
        #expect(identityBlocker.check(identity: testIdentity) == .blocked)
    }

    @Test func `10: If unknown contacts are blocked and the contact is hidden and not part of an not left group is it blocked`(
    ) async throws {
        let testIdentity = try ThreemaIdentity(identity: "ABCDEFGH")
        
        let contactEntity = testDatabase.preparer.createContact(identity: testIdentity.rawValue)
        contactEntity.isHidden = true
        
        let (_, groupEntity, _) = testDatabase.preparer.createGroup(
            groupCreatorIdentity: testIdentity.rawValue,
            members: []
        )
        groupEntity.state = GroupState.left.rawValue as NSNumber
        
        let identityBlocker = createIdentityBlocker(blockUnknown: true)
        
        #expect(identityBlocker.check(identity: testIdentity) == .blocked)
    }

    // MARK: - Helper
    
    private func createIdentityBlocker(
        blockUnknown: Bool,
        blocklist: [ThreemaIdentity]? = nil,
    ) -> IdentityBlocker {
        let settingStoreMock = SettingsStoreMock()
        settingStoreMock.blockUnknown = blockUnknown
        if let blocklist {
            settingStoreMock.blacklist = Set(blocklist.map(\.rawValue))
        }
        
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.entityManager,
            settingsStore: settingStoreMock
        )
        
        return IdentityBlocker(businessInjector: businessInjectorMock)
    }
}
