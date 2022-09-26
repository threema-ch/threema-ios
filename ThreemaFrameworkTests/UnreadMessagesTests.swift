//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
    
    private var testDataContact: Contact!
    private var testDataConversation: Conversation!
    private var testDataMessage1: BaseMessage!

    override func setUpWithError() throws {
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        (_, mainCnx, _) = DatabasePersistentContext.devNullContext()

        // Setup DB for testing
        let dp = DatabasePreparer(context: mainCnx)
        dp.save {
            self.testDataContact = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER01",
                verificationLevel: 0
            )
            self.testDataConversation = dp
                .createConversation(marked: false, typing: false, unreadMessageCount: 1) { conversation in
                    self.testDataMessage1 = dp.createTextMessage(
                        conversation: conversation,
                        text: "msg1",
                        date: Date(),
                        delivered: true,
                        id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                        isOwn: false,
                        read: false,
                        sent: true,
                        userack: false,
                        sender: self.testDataContact
                    )
                }
        }
    }

    override func tearDownWithError() throws { }

    func testCount() throws {
        let unreadMessages =
            UnreadMessages(entityManager: EntityManager(databaseContext: DatabaseContext(
                mainContext: mainCnx,
                backgroundContext: nil
            )))
        let count = unreadMessages.totalCount()
        
        XCTAssertEqual(count, 1)
    }
}
