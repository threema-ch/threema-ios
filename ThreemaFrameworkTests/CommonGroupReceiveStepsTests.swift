//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class CommonGroupReceiveStepsTests: XCTestCase {

    private var databaseMainContext: DatabaseContext!
    private var databasePreparer: DatabasePreparer!
        
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, mainContext, _) = DatabasePersistentContext.devNullContext()
        databaseMainContext = DatabaseContext(mainContext: mainContext, backgroundContext: nil)
        databasePreparer = DatabasePreparer(context: mainContext)
    }

    // MARK: No group
    
    func testNoGroupWithMeAsCreator() {
        let expectedResult: CommonGroupReceiveSteps.Result = .discardMessage
        
        let businessInjector = BusinessInjectorMock(
            entityManager: EntityManager()
        )

        let groupID = MockData.generateGroupID()
        let creator = ThreemaIdentity(businessInjector.myIdentityStore.identity)
        let groupIdentity = GroupIdentity(id: groupID, creator: creator)
        
        let sender = ThreemaIdentity("MEMBER01")
        
        let commonGroupReceiveSteps = CommonGroupReceiveSteps(businessInjector: businessInjector)
        let actualResult = commonGroupReceiveSteps.run(for: groupIdentity, sender: sender)
        
        XCTAssertEqual(actualResult, expectedResult)
    }
    
    func testNoGroupWithOtherCreator() throws {
        let expectedResult: CommonGroupReceiveSteps.Result = .discardMessage
        
        let businessInjector = BusinessInjectorMock(
            entityManager: EntityManager()
        )

        let groupID = MockData.generateGroupID()
        let creator = ThreemaIdentity("CREATOR1")
        let groupIdentity = GroupIdentity(id: groupID, creator: creator)
        
        let sender = ThreemaIdentity("MEMBER01")
        
        let commonGroupReceiveSteps = CommonGroupReceiveSteps(businessInjector: businessInjector)
        let actualResult = commonGroupReceiveSteps.run(for: groupIdentity, sender: sender)
        
        let groupManagerMock: GroupManagerMock = try XCTUnwrap(businessInjector.groupManager as? GroupManagerMock)
        
        XCTAssertEqual(actualResult, expectedResult)
        
        // This should send a sync request to the creator
        XCTAssertEqual(groupManagerMock.sendSyncRequestCalls.count, 1)
        XCTAssertEqual(groupManagerMock.sendSyncRequestCalls[0].creator, creator)
    }
    
    // MARK: Left group
    
    func testLeftGroupWithMeAsCreator() throws {
        let expectedResult: CommonGroupReceiveSteps.Result = .discardMessage

        let groupManagerMock = GroupManagerMock()
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainContext),
            groupManager: groupManagerMock
        )
        
        let groupID = MockData.generateGroupID()
        let creator = ThreemaIdentity(businessInjectorMock.myIdentityStore.identity)
        let groupIdentity = GroupIdentity(id: groupID, creator: creator)
        
        let members = [
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
        ]
        
        let sender = members[0]
        
        var group: Group!

        databasePreparer.save {
            var dbMembers = [ContactEntity]()
            for member in members {
                dbMembers.append(databasePreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member.string
                ))
            }
            
            let dbGroup = databasePreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: nil // Creator needs to be nil if my identity is the creator
            )
            dbGroup.state = NSNumber(integerLiteral: 2) // GroupStateLeft
            
            let dbConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { dbConversation in
                // swiftformat:disable:next acronyms
                dbConversation.groupId = dbGroup.groupId
                dbConversation.groupMyIdentity = businessInjectorMock.myIdentityStore.identity
                dbConversation.members = Set<ContactEntity>(dbMembers)
            }

            group = Group(
                myIdentityStore: businessInjectorMock.myIdentityStore,
                userSettings: businessInjectorMock.userSettings,
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }
        
        groupManagerMock.getGroupReturns.append(group)

        let commonGroupReceiveSteps = CommonGroupReceiveSteps(businessInjector: businessInjectorMock)
        let actualResult = commonGroupReceiveSteps.run(for: groupIdentity, sender: sender)
                
        XCTAssertEqual(actualResult, expectedResult)
        
        // One dissolve message should be sent to the sender
        XCTAssertEqual(groupManagerMock.dissolveCalls.count, 1)
        let firstDissolveCall = try XCTUnwrap(groupManagerMock.dissolveCalls.first)
        XCTAssertEqual(firstDissolveCall.groupID, groupID)
        XCTAssertEqual(firstDissolveCall.receivers, Set([sender.string]))
    }
    
    func testForceLeftGroupWithMeAsCreator() throws {
        let expectedResult: CommonGroupReceiveSteps.Result = .discardMessage
        
        let groupManagerMock = GroupManagerMock()
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainContext),
            groupManager: groupManagerMock
        )
        
        let groupID = MockData.generateGroupID()
        let creator = ThreemaIdentity(businessInjectorMock.myIdentityStore.identity)
        let groupIdentity = GroupIdentity(id: groupID, creator: creator)
        
        let members = [
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
        ]
        
        let sender = members[0]
        
        var group: Group!
        
        databasePreparer.save {
            var dbMembers = [ContactEntity]()
            for member in members {
                dbMembers.append(databasePreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member.string
                ))
            }
            
            let dbGroup = databasePreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: nil // Creator needs to be nil if my identity is the creator
            )
            dbGroup.state = NSNumber(integerLiteral: 3) // GroupStateForcedLeft
            
            let dbConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { dbConversation in
                // swiftformat:disable:next acronyms
                dbConversation.groupId = dbGroup.groupId
                dbConversation.groupMyIdentity = businessInjectorMock.myIdentityStore.identity
                dbConversation.members = Set<ContactEntity>(dbMembers)
            }
            
            group = Group(
                myIdentityStore: businessInjectorMock.myIdentityStore,
                userSettings: businessInjectorMock.userSettings,
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }
        
        groupManagerMock.getGroupReturns.append(group)

        let commonGroupReceiveSteps = CommonGroupReceiveSteps(businessInjector: businessInjectorMock)
        let actualResult = commonGroupReceiveSteps.run(for: groupIdentity, sender: sender)
        
        XCTAssertEqual(actualResult, expectedResult)
        
        // One dissolve message should be sent to the sender
        XCTAssertEqual(groupManagerMock.dissolveCalls.count, 1)
        let firstDissolveCall = try XCTUnwrap(groupManagerMock.dissolveCalls.first)
        XCTAssertEqual(firstDissolveCall.groupID, groupID)
        XCTAssertEqual(firstDissolveCall.receivers, Set([sender.string]))
    }
    
    func testLeftGroupWithOtherCreator() throws {
        let expectedResult: CommonGroupReceiveSteps.Result = .discardMessage

        let groupManagerMock = GroupManagerMock()
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainContext),
            groupManager: groupManagerMock
        )
        
        let groupID = MockData.generateGroupID()
        let creator = ThreemaIdentity("CREATOR1")
        let groupIdentity = GroupIdentity(id: groupID, creator: creator)
        
        let members = [
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
        ]
        
        let sender = members[0]
        
        var group: Group!

        databasePreparer.save {
            let dbCreator = databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: creator.string
            )
            
            var dbMembers = [ContactEntity]()
            for member in members {
                dbMembers.append(databasePreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member.string
                ))
            }
            
            let dbGroup = databasePreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: creator.string
            )
            dbGroup.state = NSNumber(integerLiteral: 2) // GroupStateLeft
            
            let dbConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { dbConversation in
                // swiftformat:disable:next acronyms
                dbConversation.groupId = dbGroup.groupId
                dbConversation.groupMyIdentity = businessInjectorMock.myIdentityStore.identity
                dbConversation.members = Set<ContactEntity>(dbMembers)
                dbConversation.contact = dbCreator
            }

            group = Group(
                myIdentityStore: businessInjectorMock.myIdentityStore,
                userSettings: businessInjectorMock.userSettings,
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }
        
        groupManagerMock.getGroupReturns.append(group)

        let commonGroupReceiveSteps = CommonGroupReceiveSteps(businessInjector: businessInjectorMock)
        let actualResult = commonGroupReceiveSteps.run(for: groupIdentity, sender: sender)
                
        XCTAssertEqual(actualResult, expectedResult)
        
        // No group dissolve
        XCTAssertEqual(groupManagerMock.dissolveCalls.count, 0)
        
        // One group left message to sender
        XCTAssertEqual(groupManagerMock.leaveCalls.count, 1)
        let firstLeaveCall = try XCTUnwrap(groupManagerMock.leaveCalls.first)
        XCTAssertEqual(firstLeaveCall.groupIdentity, groupIdentity)
        XCTAssertEqual(firstLeaveCall.receivers, [sender.string])
    }
    
    func testForceLeftGroupWithOtherCreator() throws {
        let expectedResult: CommonGroupReceiveSteps.Result = .discardMessage

        let groupManagerMock = GroupManagerMock()
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainContext),
            groupManager: groupManagerMock
        )
        
        let groupID = MockData.generateGroupID()
        let creator = ThreemaIdentity("CREATOR1")
        let groupIdentity = GroupIdentity(id: groupID, creator: creator)
        
        let members = [
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
        ]
        
        let sender = members[0]
        
        var group: Group!

        databasePreparer.save {
            let dbCreator = databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: creator.string
            )
            
            var dbMembers = [ContactEntity]()
            for member in members {
                dbMembers.append(databasePreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member.string
                ))
            }
            
            let dbGroup = databasePreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: creator.string
            )
            dbGroup.state = NSNumber(integerLiteral: 3) // GroupStateForceLeft
            
            let dbConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { dbConversation in
                // swiftformat:disable:next acronyms
                dbConversation.groupId = dbGroup.groupId
                dbConversation.groupMyIdentity = businessInjectorMock.myIdentityStore.identity
                dbConversation.members = Set<ContactEntity>(dbMembers)
                dbConversation.contact = dbCreator
            }

            group = Group(
                myIdentityStore: businessInjectorMock.myIdentityStore,
                userSettings: businessInjectorMock.userSettings,
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }
        
        groupManagerMock.getGroupReturns.append(group)

        let commonGroupReceiveSteps = CommonGroupReceiveSteps(businessInjector: businessInjectorMock)
        let actualResult = commonGroupReceiveSteps.run(for: groupIdentity, sender: sender)
                
        XCTAssertEqual(actualResult, expectedResult)
        
        // No dissolve message
        XCTAssertEqual(groupManagerMock.dissolveCalls.count, 0)
        
        // One group left message to sender
        XCTAssertEqual(groupManagerMock.leaveCalls.count, 1)
        let firstLeaveCall = try XCTUnwrap(groupManagerMock.leaveCalls.first)
        XCTAssertEqual(firstLeaveCall.groupIdentity, groupIdentity)
        XCTAssertEqual(firstLeaveCall.receivers, [sender.string])
    }
    
    // MARK: No member
    
    func testSenderNoMemberWithMeAsCreator() throws {
        let expectedResult: CommonGroupReceiveSteps.Result = .discardMessage

        let groupManagerMock = GroupManagerMock()
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainContext),
            groupManager: groupManagerMock
        )
        
        let groupID = MockData.generateGroupID()
        let creator = ThreemaIdentity(businessInjectorMock.myIdentityStore.identity)
        let groupIdentity = GroupIdentity(id: groupID, creator: creator)
        
        let members = [
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
        ]
        
        let sender = ThreemaIdentity("NOMEMBER")
        
        var group: Group!

        databasePreparer.save {
            var dbMembers = [ContactEntity]()
            for member in members {
                dbMembers.append(databasePreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member.string
                ))
            }
            
            let dbGroup = databasePreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: nil // Creator needs to be nil if my identity is the creator
            )
            
            let dbConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { dbConversation in
                // swiftformat:disable:next acronyms
                dbConversation.groupId = dbGroup.groupId
                dbConversation.groupMyIdentity = businessInjectorMock.myIdentityStore.identity
                dbConversation.members = Set<ContactEntity>(dbMembers)
            }

            group = Group(
                myIdentityStore: businessInjectorMock.myIdentityStore,
                userSettings: businessInjectorMock.userSettings,
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }
        
        groupManagerMock.getGroupReturns.append(group)

        let commonGroupReceiveSteps = CommonGroupReceiveSteps(businessInjector: businessInjectorMock)
        let actualResult = commonGroupReceiveSteps.run(for: groupIdentity, sender: sender)
                
        XCTAssertEqual(actualResult, expectedResult)
        
        // One empty member list message should be sent to the sender
        XCTAssertEqual(groupManagerMock.dissolveCalls.count, 0)
        XCTAssertEqual(groupManagerMock.emptyMemberListCalls.count, 1)
        let firstEmptyMemberListCall = try XCTUnwrap(groupManagerMock.emptyMemberListCalls.first)
        XCTAssertEqual(firstEmptyMemberListCall.groupID, groupID)
        XCTAssertEqual(firstEmptyMemberListCall.receivers, Set([ThreemaIdentity(sender.string)]))
    }
    
    func testSenderNoMemberWithOtherCreator() throws {
        let expectedResult: CommonGroupReceiveSteps.Result = .discardMessage

        let groupManagerMock = GroupManagerMock()
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainContext),
            groupManager: groupManagerMock
        )
        
        let groupID = MockData.generateGroupID()
        let creator = ThreemaIdentity("CREATOR1")
        let groupIdentity = GroupIdentity(id: groupID, creator: creator)
        
        let members = [
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
        ]
        
        let sender = ThreemaIdentity("NOMEMBER")

        var group: Group!

        databasePreparer.save {
            let dbCreator = databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: creator.string
            )
            
            var dbMembers = [ContactEntity]()
            for member in members {
                dbMembers.append(databasePreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member.string
                ))
            }
            
            let dbGroup = databasePreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: creator.string
            )
            
            let dbConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { dbConversation in
                // swiftformat:disable:next acronyms
                dbConversation.groupId = dbGroup.groupId
                dbConversation.groupMyIdentity = businessInjectorMock.myIdentityStore.identity
                dbConversation.members = Set<ContactEntity>(dbMembers)
                dbConversation.contact = dbCreator
            }

            group = Group(
                myIdentityStore: businessInjectorMock.myIdentityStore,
                userSettings: businessInjectorMock.userSettings,
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }
        
        groupManagerMock.getGroupReturns.append(group)

        let commonGroupReceiveSteps = CommonGroupReceiveSteps(businessInjector: businessInjectorMock)
        let actualResult = commonGroupReceiveSteps.run(for: groupIdentity, sender: sender)
                
        XCTAssertEqual(actualResult, expectedResult)
        
        // No left message
        XCTAssertEqual(groupManagerMock.leaveCalls.count, 0)
        
        // No dissolve calls
        XCTAssertEqual(groupManagerMock.dissolveCalls.count, 0)
    }
    
    // MARK: Happy path
    
    func testKeepMessageWithOtherCreator() throws {
        let expectedResult: CommonGroupReceiveSteps.Result = .keepMessage

        let groupManagerMock = GroupManagerMock()
        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainContext),
            groupManager: groupManagerMock
        )
        
        let groupID = MockData.generateGroupID()
        let creator = ThreemaIdentity("CREATOR1")
        let groupIdentity = GroupIdentity(id: groupID, creator: creator)
        
        let members = [
            ThreemaIdentity("MEMBER01"),
            ThreemaIdentity("MEMBER02"),
            ThreemaIdentity("MEMBER03"),
        ]
        
        let sender = members[0]

        var group: Group!

        databasePreparer.save {
            let dbCreator = databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: creator.string
            )
            
            var dbMembers = [ContactEntity]()
            for member in members {
                dbMembers.append(databasePreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member.string
                ))
            }
            
            let dbGroup = databasePreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: creator.string
            )
            
            let dbConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { dbConversation in
                // swiftformat:disable:next acronyms
                dbConversation.groupId = dbGroup.groupId
                dbConversation.groupMyIdentity = businessInjectorMock.myIdentityStore.identity
                dbConversation.members = Set<ContactEntity>(dbMembers)
                dbConversation.contact = dbCreator
            }

            group = Group(
                myIdentityStore: businessInjectorMock.myIdentityStore,
                userSettings: businessInjectorMock.userSettings,
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }
        
        groupManagerMock.getGroupReturns.append(group)

        let commonGroupReceiveSteps = CommonGroupReceiveSteps(businessInjector: businessInjectorMock)
        let actualResult = commonGroupReceiveSteps.run(for: groupIdentity, sender: sender)
                
        XCTAssertEqual(actualResult, expectedResult)
                
        // No left message
        XCTAssertEqual(groupManagerMock.leaveCalls.count, 0)

        // No dissolve message
        XCTAssertEqual(groupManagerMock.dissolveCalls.count, 0)
    }
}
