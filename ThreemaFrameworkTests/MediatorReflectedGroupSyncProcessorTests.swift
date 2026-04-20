import Testing
import ThreemaEssentials
import ThreemaProtocols
@testable import ThreemaFramework

struct MediatorReflectedGroupSyncProcessorTests {

    init() {
        AppGroup.setGroupID("group.ch.threema")
    }

    @Test func deletionOfUnknownGroup() async throws {
        // Config
        let testDatabase = TestDatabase()

        let businessInjectorMock = BusinessInjectorMock(entityManager: testDatabase.entityManager)

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creator: ThreemaIdentity(rawValue: "ECHOECHO")
        )
        let expectedGroupSync = D2d_GroupSync.with { groupSync in
            let expectedDelete = D2d_GroupSync.Delete.with { deleteGroup in
                deleteGroup.groupIdentity = Common_GroupIdentity.from(expectedGroupIdentity)
            }
            groupSync.delete = expectedDelete
        }

        // Act
        await confirmation(expectedCount: 1) { confirmation in
            await withCheckedContinuation { continuation in
                let groupSyncProcessor =
                    MediatorReflectedGroupSyncProcessor(frameworkInjector: businessInjectorMock)
                groupSyncProcessor.process(groupSync: expectedGroupSync)
                    .done {
                        Issue.record("An error must be thrown")
                        confirmation()
                        continuation.resume()
                    }
                    .catch { error in
                        if case MediatorReflectedProcessorError
                            .groupToDeleteNotExists(groupIdentity: expectedGroupIdentity) = error { }
                        else {
                            Issue
                                .record(
                                    "The error must be type of `MediatorReflectedProcessorError.groupToDeleteNotExists(groupIdentity: _)`"
                                )
                        }
                        confirmation()
                        continuation.resume()
                    }
            } as Void
        }
    }

    @Test func deletionOfActiveGroup() async throws {
        // Config
        let testDatabase = TestDatabase()

        let myIdentityStoreMock = MyIdentityStoreMock()
        let groupManagerMock = GroupManagerMock(myIdentityStoreMock)
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.entityManager,
            groupManager: groupManagerMock
        )

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creator: ThreemaIdentity(rawValue: myIdentityStoreMock.identity)
        )

        let expectedGroupSync = D2d_GroupSync.with { groupSync in
            let expectedDelete = D2d_GroupSync.Delete.with { deleteGroup in
                deleteGroup.groupIdentity = Common_GroupIdentity.from(expectedGroupIdentity)
            }
            groupSync.delete = expectedDelete
        }

        let (_, groupEntity, conversationEntity) = try testDatabase.preparer.createGroup(
            groupID: expectedGroupIdentity.id,
            groupCreatorIdentity: expectedGroupIdentity.creator.rawValue,
            members: ["MEMBER01"],
            myIdentityStoreMock: myIdentityStoreMock
        )

        groupManagerMock.getGroupReturns.append(
            Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: businessInjectorMock.userSettings,
                pushSettingManager: businessInjectorMock.pushSettingManager,
                groupEntity: groupEntity,
                conversation: conversationEntity,
                lastSyncRequest: nil
            )
        )

        // Act
        await confirmation(expectedCount: 1) { confirmation in
            await withCheckedContinuation { continuation in
                let groupSyncProcessor =
                    MediatorReflectedGroupSyncProcessor(frameworkInjector: businessInjectorMock)
                groupSyncProcessor.process(groupSync: expectedGroupSync)
                    .done {
                        Issue.record("An error must be thrown")
                        confirmation()
                        continuation.resume()
                    }
                    .catch { error in
                        if case MediatorReflectedProcessorError
                            .groupToDeleteIsActive(groupIdentity: expectedGroupIdentity) = error { }
                        else {
                            Issue
                                .record(
                                    "The error must be type of `MediatorReflectedProcessorError.groupToDeleteIsActive(groupIdentity: _)`"
                                )
                        }
                        confirmation()
                        continuation.resume()
                    }
            } as Void
        }

        let groupEntities = try #require(
            testDatabase.entityManager.entityFetcher
                .groupEntities(for: expectedGroupIdentity.id)
        )
        #expect(
            groupEntities
                .count(where: {
                    $0.groupID == expectedGroupIdentity.id && $0.state.intValue == GroupEntity.GroupState.active
                        .rawValue
                }) ==
                1
        )
        let conversationEntities = try #require(testDatabase.entityManager.entityFetcher.conversationEntities())
        #expect(
            conversationEntities
                .count(where: { $0.isGroup && $0.groupID == expectedGroupIdentity.id && $0.contact == nil }) == 1
        )
    }

    @Test func deletionOfInactiveGroup() async throws {
        // Config
        let testDatabase = TestDatabase()

        let myIdentityStoreMock = MyIdentityStoreMock()
        let groupManagerMock = GroupManagerMock(myIdentityStoreMock)
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.entityManager,
            groupManager: groupManagerMock
        )

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creator: ThreemaIdentity(rawValue: myIdentityStoreMock.identity)
        )

        let expectedGroupSync = D2d_GroupSync.with { groupSync in
            let expectedDelete = D2d_GroupSync.Delete.with { deleteGroup in
                deleteGroup.groupIdentity = Common_GroupIdentity.from(expectedGroupIdentity)
            }
            groupSync.delete = expectedDelete
        }

        let (_, groupEntity, conversationEntity) = try testDatabase.preparer.createGroup(
            groupID: expectedGroupIdentity.id,
            groupCreatorIdentity: expectedGroupIdentity.creator.rawValue,
            members: ["MEMBER01"]
        )
        testDatabase.preparer.save {
            groupEntity.state = NSNumber(integerLiteral: GroupEntity.GroupState.left.rawValue)
        }

        groupManagerMock.getGroupReturns.append(
            Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: businessInjectorMock.userSettings,
                pushSettingManager: businessInjectorMock.pushSettingManager,
                groupEntity: groupEntity,
                conversation: conversationEntity,
                lastSyncRequest: nil
            )
        )

        // Act
        await confirmation(expectedCount: 1) { confirmation in
            await withCheckedContinuation { continuation in
                let groupSyncProcessor =
                    MediatorReflectedGroupSyncProcessor(frameworkInjector: businessInjectorMock)
                groupSyncProcessor.process(groupSync: expectedGroupSync)
                    .done {
                        confirmation()
                        continuation.resume()
                    }
                    .catch { error in
                        Issue.record("\(error)")
                        confirmation()
                        continuation.resume()
                    }
            } as Void
        }

        let groupEntities = try #require(
            testDatabase.entityManager.entityFetcher
                .groupEntities(for: expectedGroupIdentity.id)
        )
        #expect(
            groupEntities
                .count(where: {
                    $0.groupID == expectedGroupIdentity.id && $0.state.intValue == GroupEntity.GroupState.left
                        .rawValue
                }) ==
                1
        )
        #expect(testDatabase.entityManager.entityFetcher.conversationEntities()?.isEmpty ?? true)
    }
}
