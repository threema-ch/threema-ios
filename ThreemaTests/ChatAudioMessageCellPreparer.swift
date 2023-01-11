//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

import Foundation

@objc class ChatAudioMessageCellPreparer: NSObject, DatabasePreparerProtocol {
    @objc var persistentStoreCoordinator: NSPersistentStoreCoordinator!
    @objc var objectContext: NSManagedObjectContext!
    
    private var conversation: Conversation!
    
    @objc func prepareDatabase() {
        (_, objectContext, _) = DatabasePersistentContext.devNullContext()

        let databasePreparer = DatabasePreparer(context: objectContext)
        let contact = databasePreparer.createContact(publicKey: Data([1]), identity: "ECHOECHO", verificationLevel: 0)
        conversation = databasePreparer
            .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                conversation.contact = contact
            }
    }
    
    @objc func createAudioData() -> AudioData {
        let databasePreparer = DatabasePreparer(context: objectContext)
        return databasePreparer.createAudioData(data: nil)
    }
    
    @objc func createAudioMessageEntity() -> AudioMessageEntity {
        let databasePreparer = DatabasePreparer(context: objectContext)
        return databasePreparer.createAudioMessageEntity(conversation: conversation, duration: 1, complete: nil)
    }
}
