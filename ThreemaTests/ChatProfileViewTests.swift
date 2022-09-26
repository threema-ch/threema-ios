//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

class ChatProfileViewTests: XCTestCase {
    
    private var managedObjectContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
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
    
    private func createConversation() -> (Contact, Conversation) {
        var contact: Contact!
        var conversation: Conversation!
        
        let databasePreparer = DatabasePreparer(context: managedObjectContext)
        databasePreparer.save {
            contact = databasePreparer.createContact(publicKey: Data([1]), identity: "ECHOECHO", verificationLevel: 0)
            
            conversation = databasePreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                    conversation.contact = contact
                }
        }
        
        return (contact, conversation)
    }

    func testBasicInitialization() throws {
        let (contact, conversation) = createConversation()
        
        contact.firstName = "Emily"
        
        let expectedAccessibilityLabel =
            "\(contact.displayName ?? ""). \(contact.verificationLevelAccessibilityLabel() ?? "")"

        let chatProfileView = ChatProfileView(for: conversation)
        
        waitForMainThread()
        
        XCTAssertEqual(chatProfileView.accessibilityLabel, expectedAccessibilityLabel)
    }
    
    func testObserveNameChange() throws {
        let (contact, conversation) = createConversation()

        let chatProfileView = ChatProfileView(for: conversation)
        
        conversation.contact!.firstName = "Emily"
        let expectedAccessibilityLabel =
            "\(conversation.displayName ?? ""). \(contact.verificationLevelAccessibilityLabel() ?? "")"
        
        waitForMainThread()
        
        XCTAssertEqual(chatProfileView.accessibilityLabel, expectedAccessibilityLabel)
    }
    
    func testObserveVerificationLevelChange() throws {
        let (contact, conversation) = createConversation()

        let chatProfileView = ChatProfileView(for: conversation)
        
        contact.verificationLevel = 3
        let expectedAccessibilityLabel =
            "\(contact.displayName ?? ""). \(contact.verificationLevelAccessibilityLabel() ?? "")"
        
        waitForMainThread()
        
        XCTAssertEqual(chatProfileView.accessibilityLabel, expectedAccessibilityLabel)
    }
    
    // MARK: - Group chats
    
    private func createGroupConversation() -> Conversation {
        var conversation: Conversation!
        
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupName = "Foodies"
        let memberNames = ["MEMBER01", "MEMBER02", "MEMBER03"]
        let databasePreparer = DatabasePreparer(context: managedObjectContext)

        let members = memberNames.map { name -> Contact in
            databasePreparer.createContact(publicKey: Data([1]), identity: name, verificationLevel: 1)
        }
        
        databasePreparer.save {
            conversation = databasePreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
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
        let chatProfileView = ChatProfileView(for: conversation)
        
        conversation.groupName = groupName
        
        waitForMainThread()
        
        XCTAssertEqual(chatProfileView.accessibilityLabel, groupName)
    }
    
    func testObserveMembersChange() throws {
        let conversation = createGroupConversation()
        _ = ChatProfileView(for: conversation)
        
        conversation.members.removeFirst()
        
        // As the members list label is private we cannot assert anything.
        // This test just checks if there are any crashes due to the observers.
    }
    
    func testObserveMemberNameChange() throws {
        let conversation = createGroupConversation()
        _ = ChatProfileView(for: conversation)
        
        let contact = try XCTUnwrap(conversation.members.first)
        contact.lastName = "1stMember"
        
        // As the members list label is private we cannot assert anything.
        // This test just checks if there are any crashes due to the observers.
    }
    
    func testDoNotObserveRemovedMemberNameChange() throws {
        let conversation = createGroupConversation()
        _ = ChatProfileView(for: conversation)
        
        let contact = try XCTUnwrap(conversation.members.removeFirst())
        contact.lastName = "1stRemovedMember"
        
        // As the members list label is private we cannot assert anything.
        // This test just checks if there are any crashes due to the observers.
    }
}
