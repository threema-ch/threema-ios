//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import XCTest
@testable import ThreemaFramework

final class ConversationEntityTests: XCTestCase {
    
    // MARK: - Properties

    private var dbContext: DatabaseContext!
    
    // MARK: - Setup

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
        dbContext = DatabaseContext(mainContext: managedObjectContext, backgroundContext: nil)
    }
    
    // MARK: - Tests

    func testCreation() throws {
        // Arrange
        let category: ConversationEntity.Category = .private
        let groupID = MockData.generateGroupID()
        let groupImageSetDate = Date.now
        let groupMyIdentity = "MYIDENTI"
        let groupName = "Group Name"
        let lastTypingStart = Date.now
        let lastUpdate = Date.now
        let marked = true
        let typing = true
        let unreadMessageCount: NSNumber = 10
        let visibility: ConversationEntity.Visibility = .pinned
        
        let groupImage: ImageDataEntity? = nil
        let lastMessage: BaseMessageEntity? = nil
        let ballots: Set<BallotEntity>? = nil
        let distributionList: DistributionListEntity? = nil
        let contact: ContactEntity? = nil
        let members: Set<ContactEntity>? = nil
        
        let entityManager = EntityManager(databaseContext: dbContext)

        // Act
        let conversationEntity = try entityManager.performAndWaitSave {
            let conversationEntity = try XCTUnwrap(entityManager.entityCreator.conversationEntity())
            
            conversationEntity.changeCategory(to: category)
            // swiftformat:disable:next acronyms
            conversationEntity.groupId = groupID
            conversationEntity.groupImageSetDate = groupImageSetDate
            conversationEntity.groupMyIdentity = groupMyIdentity
            conversationEntity.groupName = groupName
            conversationEntity.lastUpdate = lastUpdate
            conversationEntity.marked = NSNumber(booleanLiteral: marked)
            conversationEntity.setTyping(to: typing)
            conversationEntity.unreadMessageCount = unreadMessageCount
            conversationEntity.changeVisibility(to: visibility)
            
            return conversationEntity
        }
        
        let fetchedConversationEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: conversationEntity.objectID) as? ConversationEntity
        )
        
        // Assert
        XCTAssertEqual(category, fetchedConversationEntity.conversationCategory)
        XCTAssertEqual(groupID, fetchedConversationEntity.groupID)
        XCTAssertEqual(groupImageSetDate, fetchedConversationEntity.groupImageSetDate)
        XCTAssertEqual(groupMyIdentity, fetchedConversationEntity.groupMyIdentity)
        XCTAssertEqual(groupName, fetchedConversationEntity.groupName)
        XCTAssertEqual(lastUpdate, fetchedConversationEntity.lastUpdate)
        XCTAssertEqual(NSNumber(booleanLiteral: marked), fetchedConversationEntity.marked)
        XCTAssertEqual(NSNumber(booleanLiteral: typing), fetchedConversationEntity.typing)
        XCTAssertEqual(unreadMessageCount, fetchedConversationEntity.unreadMessageCount)
        XCTAssertEqual(lastUpdate, fetchedConversationEntity.lastUpdate)
        XCTAssertEqual(visibility, fetchedConversationEntity.conversationVisibility)
    }
}
