//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
@testable import ThreemaFramework

final class AutomaticDeleteTests: XCTestCase {

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
    }

    /// 1. Create Messages for every `OlderThanOption` case excluding `forever` and `everything`.
    /// 2. Delete Messages on each Iteration and test if the amount before and after matches the desired output.
    func testLoadAndAutomaticDeleteTextMessages() async throws {
        // Setup
        let entityManager = EntityManager()
        let testBundle = Bundle(for: DBLoadTests.self)
        guard let textsPath = testBundle.url(forResource: "test_texts", withExtension: "json") else {
            XCTFail("Cannot find file with test texts")
            return
        }
        let texts = try JSONDecoder().decode([String].self, from: Data(contentsOf: textsPath))
        typealias Option = StorageManagementConversationView.OlderThanOption
        // Tests
        let allCases = Option.commonCases
        
        let createConversation = { (contact: String) -> ConversationEntity in
            var conversation: ConversationEntity?
            entityManager.performAndWaitSave {
                if let contact = entityManager.entityFetcher.contact(for: contact) {
                    conversation = entityManager.conversation(forContact: contact, createIfNotExisting: true)
                }
            }
            return conversation!
        }
        
        let createMessages = { (option: Option, conversation: ConversationEntity) in
            let total = (option.days ?? 0)
            for index in 0..<total {
                let calendar = Calendar.current
                let date = calendar.date(byAdding: .day, value: -(index + 1), to: option.date ?? Date.currentDate)!
                let message = entityManager.entityCreator.textMessageEntity(for: conversation, setLastUpdate: true)!
                message.text = "\(index) - \(texts[index % texts.count])"
                message.date = date
                message.sender = conversation.contact
                message.sent = true
                message.delivered = true
                message.remoteSentDate = date
                message.isOwn = false
                message.read = false
                print("\(option.localizedTitleDescription)\(index + 1)/\(total)")
            }
        }
        let userSettingsMock = UserSettingsMock()
        let mrm = MessageRetentionManagerModel(
            userSettings: userSettingsMock,
            unreadMessages: UnreadMessagesMock(),
            groupManager: GroupManagerMock(),
            entityManager: entityManager
        )
        let CONTACT = "ECHOECHO"
        _ = createContacts(for: [CONTACT])
        
        for option in allCases {
            Date.currentDate = Date.now
            
            let days = option.days ?? -1
            mrm.selection = days
            userSettingsMock.keepMessagesDays = days

            let messagesToBeCreated = option.days ?? 0
            let date = option.date ?? Date.currentDate
            var conversation: ConversationEntity!
            
            entityManager.performAndWaitSave {
                conversation = createConversation(CONTACT)
                _ = entityManager.entityDestroyer.deleteMessages(of: conversation)
                
                createMessages(option, conversation)
                
                let unreadCount = UnreadMessages(messageSender: MessageSenderMock(), entityManager: entityManager)
                    .count(for: conversation, withPerformBlockAndWait: true)
                XCTAssertEqual(messagesToBeCreated, unreadCount)
            }
            
            guard let conv = entityManager.conversation(for: CONTACT, createIfNotExisting: false) else {
                XCTFail("Conversation missing!")
                return
            }
            
            let beforeDeleteCount = await entityManager.entityDestroyer.messagesToBeDeleted(
                olderThan: date,
                for: [conv].map(\.objectID)
            )
            
            print(
                "Test MessagesToBeDeleted: \(option.localizedTitleDescription) = \(messagesToBeCreated) Messages"
            )
            XCTAssertEqual(messagesToBeCreated, beforeDeleteCount)
            
            // now delete all
            await mrm.deleteOldMessages()
            
            let afterDeleteCount = await entityManager.entityDestroyer.messagesToBeDeleted(
                olderThan: date,
                for: [conv].map(\.objectID)
            )
            print("Test Perform Message Deletion: \(option.localizedTitleDescription)")
            XCTAssertEqual(afterDeleteCount, 0)
        }
    }
    
    // MARK: - Helper
    
    private func createContacts(for ids: [String]) -> [String] {
        var createdContacts = [String]()
        var contactStoreExpectations = [XCTestExpectation]()
        for id in ids {
            print("Checking \(id)")
            let contactStoreExpectation = expectation(description: "Add contact to contact store")
            ContactStore.shared().addContact(
                with: id,
                verificationLevel: Int32(ContactEntity.VerificationLevel.unverified.rawValue)
            ) { _, _ in
                createdContacts.append(id)
                contactStoreExpectation.fulfill()
            } onError: { error in
                print("Failed to create contact from \(id) \(error.localizedDescription)")
                contactStoreExpectation.fulfill()
            }
            contactStoreExpectations.append(contactStoreExpectation)
        }
        wait(for: contactStoreExpectations, timeout: 30)
        
        return createdContacts
    }
}
