//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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
import ThreemaEssentialsTestHelper
import XCTest
@testable import ThreemaFramework

@objc class BallotMessagePreparer: NSObject, DatabasePreparerProtocol, ResourceLoaderProtocol {
    
    @objc var persistentStoreCoordinator: NSPersistentStoreCoordinator!
    @objc var objectContext: ThreemaManagedObjectContext!
    
    let groupID: Data = MockData.generateGroupID()
    let myIdentity = "TESTERID"
    @objc func prepareDatabase() {
        (persistentStoreCoordinator, objectContext, _) = DatabasePersistentContext.devNullContext()

        let databasePreparer = DatabasePreparer(context: objectContext)
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: Data([1]),
                identity: "ECHOECHO"
            )

            _ = databasePreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.groupID = self.groupID
                    conversation.groupMyIdentity = self.myIdentity
                    conversation.contact = contact
                    conversation.groupName = "TestGroup BallotMessageDecoder"
                    conversation.members?.insert(contact)
                }
        }
    }
    
    @objc func loadContentAsString(_ fileName: String, fileExtension: String) -> String? {
        ResourceLoader.contentAsString(fileName, fileExtension)
    }
}
