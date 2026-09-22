import libthreemaSwift
import Testing
import ThreemaEssentials
import UIKit
@testable @preconcurrency import ThreemaFramework

@Suite("Test libthreema GroupProvider")
struct GroupProviderTests {
    @Test(arguments: [
        GroupMembershipFilter.any,
        .onlyActive,
    ])
    func `isPartOfAnyGroup with empty database`(expectedFilter: GroupMembershipFilter) async throws {
        let (groupProvider, _, _) = try makeSUT()

        let expectedIdentity = LibthreemaThreemaID("ECHOECHO")

        let isPartOfAnyGroup = try groupProvider.isPartOfAnyGroup(identity: expectedIdentity, filter: expectedFilter)

        #expect(isPartOfAnyGroup == false)
    }

    @Test(arguments: [
        (GroupEntity.GroupState.active, GroupMembershipFilter.any, true),
        (.active, .onlyActive, true),
        (.left, .any, true),
        (.left, .onlyActive, false),
    ])
    func `isPartOfAnyGroup with inactive group`(
        expectedGroupState: GroupEntity.GroupState,
        expectedFilter: GroupMembershipFilter,
        result: Bool
    ) async throws {
        let (groupProvider, _, testDatabase) = try makeSUT()

        let expectedIdentity = LibthreemaThreemaID("ECHOECHO")

        let (_, groupEntity, _) = testDatabase.preparer.createGroup(
            groupID: BytesUtility.generateGroupID(),
            groupCreatorIdentity: "TESTID01",
            members: [expectedIdentity]
        )

        testDatabase.preparer.save {
            groupEntity.state = NSNumber(integerLiteral: expectedGroupState.rawValue)
        }

        let isPartOfAnyGroup = try groupProvider.isPartOfAnyGroup(identity: expectedIdentity, filter: expectedFilter)

        #expect(isPartOfAnyGroup == result)
    }

    @Test func `isPartOfAnyGroup identity is user identity`() async throws {
        let (groupProvider, myIdentityStoreMock, _) = try makeSUT()

        let userIdentity = LibthreemaThreemaID(myIdentityStoreMock.identity)

        #expect(throws: ProviderError.InvalidParameter("Identity must not be the user's own identity.")) {
            try groupProvider.isPartOfAnyGroup(identity: userIdentity, filter: .any)
        }
    }

    @Test func `getIdentities empty database`() throws {
        let (groupProvider, _, _) = try makeSUT()

        #expect(try groupProvider.getIdentities().isEmpty)
    }

    @Test func getIdentities() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let groupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        testDatabase.preparer.save {
            testDatabase.preparer.createGroup(
                groupID: groupIdentity.id,
                groupCreatorIdentity: groupIdentity.creator.rawValue,
                members: [],
                myIdentityStoreMock: myIdentityStoreMock
            )
        }

        let identities = try groupProvider.getIdentities()

        #expect(identities.count == 1)
        #expect(try identities.first == LibthreemaGroupIdentity(groupIdentity: groupIdentity))
    }

    @Test func `getWithProfilePicture empty database`() throws {
        let (groupProvider, myIdentityStoreMock, _) = try makeSUT()

        let libthreemaGroupIdentity = try LibthreemaGroupIdentity(
            // swiftformat:disable:next acronyms
            groupId: BytesUtility.generateGroupID().littleEndian(),
            creatorIdentity: myIdentityStoreMock.identity
        )

        #expect(try groupProvider.getWithProfilePicture(identity: libthreemaGroupIdentity) == nil)
    }

    @Test func getWithProfilePicture() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let groupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        try testDatabase.preparer.save {
            let (_, _, conversationEntity) = testDatabase.preparer.createGroup(
                groupID: groupIdentity.id,
                groupCreatorIdentity: groupIdentity.creator.rawValue,
                members: [],
                myIdentityStoreMock: myIdentityStoreMock
            )

            let (imageData, image) = try getValidImageData()
            conversationEntity.groupImage = testDatabase.preparer.createImageDataEntity(
                data: imageData,
                height: Int16(image.size.height),
                width: Int16(image.size.width)
            )
        }

        let libthreemaGroupIdentity = try LibthreemaGroupIdentity(groupIdentity: groupIdentity)

        let groupWithProfilePicture = try #require(
            try groupProvider.getWithProfilePicture(identity: libthreemaGroupIdentity)
        )

        #expect(groupWithProfilePicture.group.name.isEmpty)
        #expect(groupWithProfilePicture.group.members.isEmpty)
        #expect(groupWithProfilePicture.group.identity == libthreemaGroupIdentity)
        #expect(groupWithProfilePicture.group.conversationCategory == .default)
        #expect(groupWithProfilePicture.group.conversationVisibility == .normal)
        #expect(groupWithProfilePicture.group.userState == .member)
        #expect(groupWithProfilePicture.group.createdAt.date! != .now)
        #expect(groupWithProfilePicture.group.lastUpdateAt == nil)
        #expect(groupWithProfilePicture.group.notificationTriggerPolicyOverride == .none)
        #expect(groupWithProfilePicture.profilePicture != nil)
    }

    @Test(arguments: [
        ([ThreemaIdentity("MEMBER01")], 1),
        ([ThreemaIdentity("MEMBER01"), ThreemaIdentity("MEMBER01")], 1),
        ([ThreemaIdentity("MEMBER01"), ThreemaIdentity("MEMBER02")], 2),
        ([], 0),
    ])
    func `addWithProfilePicture regular group`(expectedMembers: [ThreemaIdentity], expectedMembersCount: Int) throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        testDatabase.preparer.save {
            for expectedMember in Set(expectedMembers) {
                testDatabase.preparer.createContact(identity: expectedMember.rawValue)
            }
        }

        let groupWithProfilePicture = try GroupWithProfilePicture(
            group: getLibthreemaGroup(groupIdentity: expectedGroupIdentity, members: expectedMembers),
            profilePicture: nil
        )

        try groupProvider.addWithProfilePicture(groups: [groupWithProfilePicture])

        #expect(testDatabase.entityManager.entityFetcher.allGroupEntities()?.count == 1)
        _ = try #require(testDatabase.entityManager.entityFetcher.groupEntity(
            for: expectedGroupIdentity,
            myIdentity: myIdentityStoreMock.identity
        ))
        let conversationEntity = try #require(testDatabase.entityManager.entityFetcher.conversationEntity(
            for: expectedGroupIdentity,
            myIdentity: myIdentityStoreMock.identity
        ))
        let members = try #require(conversationEntity.members)
        #expect(members.count == expectedMembersCount)
        #expect(members.isEmpty || members.contains(where: { expectedMembers.map(\.rawValue).contains($0.identity) }))
        #expect(conversationEntity.groupImage == nil)
        #expect(conversationEntity.groupImageSetDate == nil)
    }

    @Test func `addWithProfilePicture group already exists`() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        testDatabase.preparer.save {
            testDatabase.preparer.createGroup(
                groupID: expectedGroupIdentity.id,
                groupCreatorIdentity: expectedGroupIdentity.creator.rawValue,
                members: [],
                myIdentityStoreMock: myIdentityStoreMock
            )
        }

        let groupWithProfilePicture = try GroupWithProfilePicture(
            group: getLibthreemaGroup(groupIdentity: expectedGroupIdentity, members: []),
            profilePicture: nil
        )

        #expect(throws: ProviderError.InvalidState("Group already exists")) {
            try groupProvider.addWithProfilePicture(groups: [groupWithProfilePicture])
        }
    }

    @Test func `addWithProfilePicture unknown group creator`() throws {
        let (groupProvider, _, _) = try makeSUT()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: "CREATOR1"
        )

        let groupWithProfilePicture = try GroupWithProfilePicture(
            group: getLibthreemaGroup(groupIdentity: expectedGroupIdentity, members: []),
            profilePicture: nil
        )

        #expect(throws: ProviderError.InvalidState("Unknown group creator")) {
            try groupProvider.addWithProfilePicture(groups: [groupWithProfilePicture])
        }
    }

    @Test func `addWithProfilePicture external group creator`() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let creatorIdentity = "CREATOR1"
        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: creatorIdentity
        )
        let expectedMembers = [ThreemaIdentity("MEMBER01")]

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: creatorIdentity)
            for member in expectedMembers {
                testDatabase.preparer.createContact(identity: member.rawValue)
            }
        }

        let groupWithProfilePicture = try GroupWithProfilePicture(
            group: getLibthreemaGroup(groupIdentity: expectedGroupIdentity, members: expectedMembers),
            profilePicture: nil
        )

        try groupProvider.addWithProfilePicture(groups: [groupWithProfilePicture])

        let groupEntity = try #require(testDatabase.entityManager.entityFetcher.groupEntity(
            for: expectedGroupIdentity,
            myIdentity: myIdentityStoreMock.identity
        ))
        #expect(groupEntity.groupCreator == creatorIdentity)
        let conversationEntity = try #require(testDatabase.entityManager.entityFetcher.conversationEntity(
            for: expectedGroupIdentity,
            myIdentity: myIdentityStoreMock.identity
        ))
        #expect(conversationEntity.contact?.identity == creatorIdentity)
    }

    @Test(arguments: [
        [ThreemaIdentity("TESTERID")],
        [ThreemaIdentity("MEMBER01")],
        [ThreemaIdentity("TESTERID"), ThreemaIdentity("MEMBER02")],
        [ThreemaIdentity("MEMBER01"), ThreemaIdentity("MEMBER02")],
        [ThreemaIdentity("TESTERID"), ThreemaIdentity("MEMBER01"), ThreemaIdentity("MEMBER02")],
    ])
    func `addWithProfilePicture unknown member`(expectedMembers: [ThreemaIdentity]) throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT(userIdentity: "TESTERID")

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: "MEMBER02")
        }

        let groupWithProfilePicture = try GroupWithProfilePicture(
            group: getLibthreemaGroup(groupIdentity: expectedGroupIdentity, members: expectedMembers),
            profilePicture: nil
        )

        #expect(throws: ProviderError.InvalidState("Not all members known contacts")) {
            try groupProvider.addWithProfilePicture(groups: [groupWithProfilePicture])
        }
    }

    @Test func `addWithProfilePicture with valid profile picture`() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )
        let expectedMembers = [ThreemaIdentity("MEMBER01")]

        testDatabase.preparer.save {
            for member in expectedMembers {
                testDatabase.preparer.createContact(identity: member.rawValue)
            }
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let validImageData = renderer.jpegData(withCompressionQuality: 1.0) { _ in }

        let groupWithProfilePicture = try GroupWithProfilePicture(
            group: getLibthreemaGroup(groupIdentity: expectedGroupIdentity, members: expectedMembers),
            profilePicture: ProfilePicture(mediaType: .jpeg, data: validImageData)
        )

        try groupProvider.addWithProfilePicture(groups: [groupWithProfilePicture])

        let conversationEntity = try #require(testDatabase.entityManager.entityFetcher.conversationEntity(
            for: expectedGroupIdentity,
            myIdentity: myIdentityStoreMock.identity
        ))
        #expect(conversationEntity.groupImage != nil)
        #expect(conversationEntity.groupImageSetDate != nil)
    }

    @Test func `addWithProfilePicture with invalid profile picture data`() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )
        let expectedMembers = [ThreemaIdentity("MEMBER01")]

        testDatabase.preparer.save {
            for member in expectedMembers {
                testDatabase.preparer.createContact(identity: member.rawValue)
            }
        }

        let groupWithProfilePicture = try GroupWithProfilePicture(
            group: getLibthreemaGroup(groupIdentity: expectedGroupIdentity, members: expectedMembers),
            profilePicture: ProfilePicture(mediaType: .jpeg, data: Data([0x00, 0x01, 0x02, 0x03]))
        )

        #expect {
            try groupProvider.addWithProfilePicture(groups: [groupWithProfilePicture])
        } throws: { error in
            error is GroupProviderError
        }
    }

    @Test func `addWithProfilePicture empty groups array`() throws {
        let (groupProvider, _, testDatabase) = try makeSUT()

        try groupProvider.addWithProfilePicture(groups: [])

        #expect((testDatabase.entityManager.entityFetcher.allGroupEntities()?.count ?? 0) == 0)
    }

    @Test func `addWithProfilePicture multiple groups`() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let groupIdentity1 = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )
        let groupIdentity2 = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )
        let expectedMembers = [ThreemaIdentity("MEMBER01")]

        testDatabase.preparer.save {
            for member in expectedMembers {
                testDatabase.preparer.createContact(identity: member.rawValue)
            }
        }

        let groups = try [
            GroupWithProfilePicture(
                group: getLibthreemaGroup(groupIdentity: groupIdentity1, members: expectedMembers),
                profilePicture: nil
            ),
            GroupWithProfilePicture(
                group: getLibthreemaGroup(groupIdentity: groupIdentity2, members: expectedMembers),
                profilePicture: nil
            ),
        ]

        try groupProvider.addWithProfilePicture(groups: groups)

        #expect(testDatabase.entityManager.entityFetcher.allGroupEntities()?.count == 2)
        _ = try #require(testDatabase.entityManager.entityFetcher.groupEntity(
            for: groupIdentity1,
            myIdentity: myIdentityStoreMock.identity
        ))
        _ = try #require(testDatabase.entityManager.entityFetcher.groupEntity(
            for: groupIdentity2,
            myIdentity: myIdentityStoreMock.identity
        ))
    }

    @Test func `addWithProfilePicture duplicate group in same call`() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )
        let expectedMembers = [ThreemaIdentity("MEMBER01")]

        testDatabase.preparer.save {
            for member in expectedMembers {
                testDatabase.preparer.createContact(identity: member.rawValue)
            }
        }

        let groupWithProfilePicture = try GroupWithProfilePicture(
            group: getLibthreemaGroup(groupIdentity: expectedGroupIdentity, members: expectedMembers),
            profilePicture: nil
        )

        #expect(throws: ProviderError.InvalidState("Group already exists")) {
            try groupProvider.addWithProfilePicture(groups: [groupWithProfilePicture, groupWithProfilePicture])
        }
    }

    @Test func `setProfilePicture group not found`() throws {
        let (groupProvider, myIdentityStoreMock, _) = try makeSUT()

        let groupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        #expect(throws: ProviderError.InvalidState("Group not found")) {
            try groupProvider.setProfilePicture(
                identity: LibthreemaGroupIdentity(groupIdentity: groupIdentity),
                profilePicture: nil
            )
        }
    }

    @Test func `setProfilePicture conversation not found`() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let groupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        testDatabase.preparer.save {
            testDatabase.preparer.createGroupEntity(groupID: groupIdentity.id, groupCreator: nil)
        }

        #expect(throws: ProviderError.InvalidState("Conversation for group not found")) {
            try groupProvider.setProfilePicture(
                identity: LibthreemaGroupIdentity(groupIdentity: groupIdentity),
                profilePicture: nil
            )
        }
    }

    @Test func `setProfilePicture with valid profile picture`() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let groupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        testDatabase.preparer.save {
            testDatabase.preparer.createGroup(
                groupID: groupIdentity.id,
                groupCreatorIdentity: groupIdentity.creator.rawValue,
                members: [],
                myIdentityStoreMock: myIdentityStoreMock
            )
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let validImageData = renderer.jpegData(withCompressionQuality: 1.0) { _ in }

        try groupProvider.setProfilePicture(
            identity: LibthreemaGroupIdentity(groupIdentity: groupIdentity),
            profilePicture: ProfilePicture(mediaType: .jpeg, data: validImageData)
        )

        let conversationEntity = try #require(testDatabase.entityManager.entityFetcher.conversationEntity(
            for: groupIdentity,
            myIdentity: myIdentityStoreMock.identity
        ))
        #expect(conversationEntity.groupImage != nil)
    }

    @Test func `setProfilePicture with nil profile picture clears image`() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let groupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        try testDatabase.preparer.save {
            let (_, _, conversationEntity) = testDatabase.preparer.createGroup(
                groupID: groupIdentity.id,
                groupCreatorIdentity: groupIdentity.creator.rawValue,
                members: [],
                myIdentityStoreMock: myIdentityStoreMock
            )

            let (imageData, image) = try getValidImageData()
            conversationEntity.groupImage = testDatabase.preparer.createImageDataEntity(
                data: imageData,
                height: Int16(image.size.height),
                width: Int16(image.size.width)
            )
        }

        try groupProvider.setProfilePicture(
            identity: LibthreemaGroupIdentity(groupIdentity: groupIdentity),
            profilePicture: nil
        )

        let conversationEntity = try #require(testDatabase.entityManager.entityFetcher.conversationEntity(
            for: groupIdentity,
            myIdentity: myIdentityStoreMock.identity
        ))
        #expect(conversationEntity.groupImage == nil)
    }

    @Test func `setProfilePicture with invalid profile picture data`() throws {
        let (groupProvider, myIdentityStoreMock, testDatabase) = try makeSUT()

        let groupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        testDatabase.preparer.save {
            testDatabase.preparer.createGroup(
                groupID: groupIdentity.id,
                groupCreatorIdentity: groupIdentity.creator.rawValue,
                members: [],
                myIdentityStoreMock: myIdentityStoreMock
            )
        }

        #expect(throws: GroupProviderError.loadUIImageFailed) {
            try groupProvider.setProfilePicture(
                identity: LibthreemaGroupIdentity(groupIdentity: groupIdentity),
                profilePicture: ProfilePicture(mediaType: .jpeg, data: Data([0x00, 0x01, 0x02, 0x03]))
            )
        }
    }

    // MARK: Private functions

    private func getLibthreemaGroup(groupIdentity: ThreemaEssentials.GroupIdentity, members: [ThreemaIdentity]) throws -> LibthreemaGroup {
        try LibthreemaGroup(
            identity: LibthreemaGroupIdentity(groupIdentity: groupIdentity),
            name: "Group name",
            createdAt: Date.now.millisecondsSince1970,
            lastUpdateAt: nil,
            userState: .member,
            members: members.map(\.rawValue),
            notificationTriggerPolicyOverride: nil,
            conversationCategory: .default,
            conversationVisibility: .normal
        )
    }

    private func getValidImageData() throws -> (Data, UIImage) {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let data = renderer.jpegData(withCompressionQuality: 1.0) { _ in }
        let image = try #require(UIImage(data: data))
        return (data, image)
    }

    private func makeSUT(userIdentity: String? = nil) throws -> (
        ThreemaFramework.GroupProvider,
        MyIdentityStoreMock,
        TestDatabase
    ) {
        let testDatabase = TestDatabase()
        let myIdentityStoreMock = MyIdentityStoreMock()
        if let userIdentity {
            myIdentityStoreMock.identity = userIdentity
        }
        let groupProvider = try GroupProvider(
            userIdentity: ThreemaIdentity(identity: myIdentityStoreMock.identity),
            pushSettingManager: PushSettingManagerMock(),
            entityManager: testDatabase.entityManager
        )
        return (groupProvider, myIdentityStoreMock, testDatabase)
    }
}
