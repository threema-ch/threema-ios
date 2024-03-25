//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

import CoreData
import XCTest
@testable import ThreemaFramework

class UnreadMessagesTests: XCTestCase {
    
    private var mainCnx: NSManagedObjectContext!
    
    private var testDataConversation1: Conversation!
    private var testDataConversation2: Conversation!
    private var testDataConversation3: Conversation!

    override func setUpWithError() throws {
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        (_, mainCnx, _) = DatabasePersistentContext.devNullContext()

        // Setup DB for testing
        let dp = DatabasePreparer(context: mainCnx)
        dp.save {
            let contact1 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER01",
                verificationLevel: 0
            )
            self.testDataConversation1 = dp
                .createConversation(typing: false, unreadMessageCount: 2, visibility: .default) { conversation in
                    dp.createTextMessage(
                        conversation: conversation,
                        text: "msg1",
                        date: Date(),
                        delivered: true,
                        id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                        isOwn: false,
                        read: false,
                        sent: true,
                        userack: false,
                        sender: contact1,
                        remoteSentDate: Date(timeIntervalSinceNow: -100)
                    )
                }

            let contact2 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER02",
                verificationLevel: 0
            )
            self.testDataConversation2 = dp
                .createConversation(typing: false, unreadMessageCount: 3, visibility: .default) { conversation in
                    dp.createTextMessage(
                        conversation: conversation,
                        text: "msg1",
                        date: Date(),
                        delivered: true,
                        id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                        isOwn: false,
                        read: false,
                        sent: true,
                        userack: false,
                        sender: contact2,
                        remoteSentDate: Date(timeIntervalSinceNow: -100)
                    )
                    dp.createTextMessage(
                        conversation: conversation,
                        text: "msg2",
                        date: Date(),
                        delivered: true,
                        id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                        isOwn: false,
                        read: false,
                        sent: true,
                        userack: false,
                        sender: contact2,
                        remoteSentDate: Date(timeIntervalSinceNow: -100)
                    )
                    dp.createTextMessage(
                        conversation: conversation,
                        text: "msg3",
                        date: Date(),
                        delivered: true,
                        id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                        isOwn: false,
                        read: true,
                        sent: true,
                        userack: false,
                        sender: contact2,
                        remoteSentDate: Date(timeIntervalSinceNow: -100)
                    )
                }

            let contact3 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER03",
                verificationLevel: 0
            )
            self.testDataConversation3 = dp
                .createConversation(typing: false, unreadMessageCount: -1, visibility: .default) { conversation in
                    dp.createTextMessage(
                        conversation: conversation,
                        text: "msg1",
                        date: Date(),
                        delivered: true,
                        id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                        isOwn: false,
                        read: true,
                        sent: true,
                        userack: false,
                        sender: contact3,
                        remoteSentDate: Date(timeIntervalSinceNow: -100)
                    )
                }
        }
    }

    override func tearDownWithError() throws { }

    func testTotalCount() throws {
        let unreadMessages =
            UnreadMessages(
                messageSender: MessageSenderMock(),
                entityManager: EntityManager(databaseContext: DatabaseContext(
                    mainContext: mainCnx,
                    backgroundContext: nil
                ))
            )
        let count = unreadMessages.totalCount()
        
        XCTAssertEqual(count, 6)
    }

    func testTotalCountWithRecalculateConversation1() throws {
        let unreadMessages =
            UnreadMessages(
                messageSender: MessageSenderMock(),
                entityManager: EntityManager(databaseContext: DatabaseContext(
                    mainContext: mainCnx,
                    backgroundContext: nil
                ))
            )
        let count = unreadMessages.totalCount(doCalcUnreadMessagesCountOf: [testDataConversation1])

        XCTAssertEqual(count, 5)
        XCTAssertEqual(testDataConversation1.unreadMessageCount, 1)
    }

    func testTotalCountWithRecalculateAllConversations() throws {
        let unreadMessages =
            UnreadMessages(
                messageSender: MessageSenderMock(),
                entityManager: EntityManager(databaseContext: DatabaseContext(
                    mainContext: mainCnx,
                    backgroundContext: nil
                ))
            )
        let count = unreadMessages
            .totalCount(doCalcUnreadMessagesCountOf: [
                testDataConversation1,
                testDataConversation2,
                testDataConversation3,
            ])

        XCTAssertEqual(count, 4)
        XCTAssertEqual(testDataConversation1.unreadMessageCount, 1)
        XCTAssertEqual(testDataConversation2.unreadMessageCount, 2)
        XCTAssertEqual(testDataConversation3.unreadMessageCount, -1)
    }

    func testCountWithRecalculateConversation1() throws {
        let unreadMessages =
            UnreadMessages(
                messageSender: MessageSenderMock(),
                entityManager: EntityManager(
                    databaseContext: DatabaseContext(
                        mainContext: mainCnx,
                        backgroundContext: nil
                    )
                )
            )
        let count = unreadMessages.count(for: testDataConversation1)

        XCTAssertEqual(count, 1)
        XCTAssertEqual(testDataConversation1.unreadMessageCount, 1)
    }
}
