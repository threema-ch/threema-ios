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

final class PushSettingTests: XCTestCase {
    private var databasePreparer: DatabasePreparer!
    private var conversation: Conversation!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
        
        databasePreparer = DatabasePreparer(context: managedObjectContext)
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
        }
    }
    
    func testEncodeDecodeIdentityWithDefaultValues() throws {
        var pushSetting = PushSetting(identity: ThreemaIdentity("ECHOECHO"))

        let encoder = JSONEncoder()
        let data = try encoder.encode(pushSetting)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        var result = try decoder.decode(PushSetting.self, from: data)

        XCTAssertEqual(result.identity, pushSetting.identity)
        XCTAssertNil(result.groupIdentity)
        XCTAssertEqual(result.type, pushSetting.type)
        XCTAssertEqual(result.muted, pushSetting.muted)
        XCTAssertEqual(result.mentioned, pushSetting.mentioned)
        XCTAssertNil(result.periodOffTillDate)
    }

    func testEncodeDecodeGroupIdentityWithDefaultValues() throws {
        var pushSetting =
            PushSetting(groupIdentity: GroupIdentity(
                id: MockData.generateGroupID(),
                creator: ThreemaIdentity("ECHOECHO")
            ))
        pushSetting.type = .offPeriod
        pushSetting.setPeriodOffTime(.time1Day)

        let encoder = JSONEncoder()
        let data = try encoder.encode(pushSetting)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        var result = try decoder.decode(PushSetting.self, from: data)

        XCTAssertNil(result.identity)
        XCTAssertEqual(result.groupIdentity, pushSetting.groupIdentity)
        XCTAssertEqual(result.type, pushSetting.type)
        XCTAssertEqual(result.muted, pushSetting.muted)
        XCTAssertEqual(result.mentioned, pushSetting.mentioned)
        XCTAssertTrue(result.periodOffTillDate?.compare(Date()) == .orderedDescending)
    }
    
    func testMentionContents() {
        var textMessage1: BaseMessage!

        databasePreparer.save {
            textMessage1 = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello @[@@@@@@@@]",
                date: Date(),
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: Date(timeIntervalSinceNow: -100)
            )
        }
        
        XCTAssertTrue(TextStyleUtils.isMeOrAllMention(inText: textMessage1.contentToCheckForMentions()))
        
        var textMessage2: BaseMessage!

        databasePreparer.save {
            textMessage2 = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello!",
                date: Date(),
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: Date(timeIntervalSinceNow: -100)
            )
        }
        
        XCTAssertFalse(TextStyleUtils.isMeOrAllMention(inText: textMessage2.contentToCheckForMentions()))

        var fileMessage1: FileMessageEntity!

        databasePreparer.save {
            fileMessage1 = databasePreparer.createFileMessageEntity(
                conversation: conversation,
                caption: "Hello @[@@@@@@@@]"
            )
        }
        
        XCTAssertTrue(TextStyleUtils.isMeOrAllMention(inText: fileMessage1.contentToCheckForMentions()))

        var fileMessage2: FileMessageEntity!

        databasePreparer.save {
            fileMessage2 = databasePreparer.createFileMessageEntity(conversation: conversation, caption: "Hello!")
        }
        
        XCTAssertFalse(TextStyleUtils.isMeOrAllMention(inText: fileMessage2.contentToCheckForMentions()))
    }
}
