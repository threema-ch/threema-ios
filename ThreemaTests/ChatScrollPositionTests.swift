//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
@testable import Threema

class ChatScrollPositionTests: XCTestCase {
    
    private var managedObjectContext: NSManagedObjectContext!

    private lazy var conversation1: ConversationEntity = {
        var conversation: ConversationEntity!
        
        let databasePreparer = DatabasePreparer(context: managedObjectContext)
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
        }
        
        return conversation
    }()
    
    private lazy var conversation2: ConversationEntity = {
        var conversation: ConversationEntity!
        
        let databasePreparer = DatabasePreparer(context: managedObjectContext)
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
        }
        
        return conversation
    }()
    
    private let chatScrollPositionInfo1 = ChatScrollPositionInfo(
        offsetFromTop: 123,
        messageObjectIDURL: URL(string: "file://test-db-entry")!,
        messageDate: Date()
    )
    
    private let chatScrollPositionInfo2 = ChatScrollPositionInfo(
        offsetFromTop: -56,
        messageObjectIDURL: URL(string: "db://another-entry")!,
        messageDate: Date()
    )
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSavingAndLoadingOfScrollPositionInfo() throws {
        let chatScrollPosition = ChatScrollPosition()
        
        chatScrollPosition.save(chatScrollPositionInfo1, for: conversation1)
        
        let actualScrollPositionInfo = try XCTUnwrap(chatScrollPosition.chatScrollPosition(for: conversation1))
        
        XCTAssertEqual(actualScrollPositionInfo, chatScrollPositionInfo1)
    }
    
    func testSavingRemovingAndLoadingOfScrollPositionInfo() throws {
        let chatScrollPosition = ChatScrollPosition()
        
        chatScrollPosition.save(chatScrollPositionInfo1, for: conversation1)
        chatScrollPosition.removeSavedPosition(for: conversation1)
        
        let actualScrollPositionInfo = chatScrollPosition.chatScrollPosition(for: conversation1)
        
        XCTAssertNil(actualScrollPositionInfo)
    }
    
    func testSavingLoadingOtherScrollPositionInfo() throws {
        let chatScrollPosition = ChatScrollPosition()
        
        chatScrollPosition.save(chatScrollPositionInfo1, for: conversation1)
        
        let actualScrollPositionInfo = chatScrollPosition.chatScrollPosition(for: conversation2)
        
        XCTAssertNil(actualScrollPositionInfo)
    }
    
    func testSavingAndLoadingMultipleScrollPositionInfo() throws {
        let chatScrollPosition = ChatScrollPosition()
        
        chatScrollPosition.save(chatScrollPositionInfo1, for: conversation1)
        chatScrollPosition.save(chatScrollPositionInfo2, for: conversation2)

        let actualScrollPositionInfo1 = try XCTUnwrap(chatScrollPosition.chatScrollPosition(for: conversation1))
        let actualScrollPositionInfo2 = try XCTUnwrap(chatScrollPosition.chatScrollPosition(for: conversation2))

        XCTAssertEqual(actualScrollPositionInfo1, chatScrollPositionInfo1)
        XCTAssertEqual(actualScrollPositionInfo2, chatScrollPositionInfo2)
    }
}
