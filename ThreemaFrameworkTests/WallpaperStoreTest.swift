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
@testable import ThreemaFramework

class WallpaperStoreTest: XCTestCase {

    // MARK: - Setup

    private let wallpaperStore = WallpaperStore.shared

    private var conversation1: ConversationEntity!
    private var conversationID1: NSManagedObjectID!

    private var conversation2: ConversationEntity!
    private var conversationID2: NSManagedObjectID!
    
    private var mainCnx: NSManagedObjectContext!
    private var entityManager: EntityManager!
    
    private let testImageURL1 = Bundle(for: WallpaperStoreTest.self)
        .url(forResource: "Bild-5-0", withExtension: "png")!
    private let testImageURL2 = Bundle(for: WallpaperStoreTest.self)
        .url(forResource: "Bild-5-1", withExtension: "png")!
    private var testImage1: UIImage!
    private var testImage2: UIImage!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        let context = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        entityManager = EntityManager(databaseContext: context)
        
        conversation1 = createConversation(
            id: "abcdefgh",
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )
        conversationID1 = conversation1.objectID
        
        conversation2 = createConversation(
            id: "abcdefg2",
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )
        conversationID2 = conversation2.objectID
        
        let data1 = try! Data(contentsOf: testImageURL1)
        testImage1 = UIImage(data: data1)!
        let data2 = try! Data(contentsOf: testImageURL2)
        testImage2 = UIImage(data: data2)!
    }

    private func createConversation(
        id: String,
        unreadMessageCount: Int,
        category: ConversationEntity.Category,
        visibility: ConversationEntity.Visibility
    ) -> ConversationEntity {
        var contact: ContactEntity!
        var conversation: ConversationEntity!

        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            contact = databasePreparer.createContact(publicKey: Data([1]), identity: id, verificationLevel: 0)

            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: unreadMessageCount,
                category: category,
                visibility: visibility
            ) { conversation in
                conversation.contact = contact
            }
        }

        return conversation
    }

    override func tearDownWithError() throws {
        wallpaperStore.deleteAllCustom()
    }

    // MARK: - Tests
    
    func testSaveDefaultWallpaper() {
        // Arrange & Act
        wallpaperStore.saveDefaultWallpaper(testImage1)
        
        // Assert
        XCTAssertEqual(wallpaperStore.wallpaper(for: conversationID1)?.pngData(), testImage1.pngData())
    }
    
    func testSaveWallpaper() {
        // Arrange
        wallpaperStore.saveDefaultWallpaper(testImage1)
        
        // Act
        wallpaperStore.saveWallpaper(testImage2, for: conversationID1)
        
        // Assert
        XCTAssertEqual(wallpaperStore.wallpaper(for: conversationID2)?.pngData(), testImage1.pngData())
        XCTAssertEqual(wallpaperStore.wallpaper(for: conversationID1)?.pngData(), testImage2.pngData())
    }
    
    func testHasCustomWallpaper() {
        // Arrange & Act
        wallpaperStore.saveDefaultWallpaper(testImage1)
        wallpaperStore.saveWallpaper(testImage2, for: conversationID1)
        
        // Assert
        XCTAssertTrue(wallpaperStore.hasCustomWallpaper(for: conversationID1))
        XCTAssertFalse(wallpaperStore.hasCustomWallpaper(for: conversationID2))
    }
    
    func testDeleteCustomWallpaper() {
        // Arrange
        wallpaperStore.saveDefaultWallpaper(testImage1)
        
        // Act
        wallpaperStore.saveWallpaper(testImage2, for: conversationID1)

        XCTAssertEqual(wallpaperStore.wallpaper(for: conversationID1)?.pngData(), testImage2.pngData())

        wallpaperStore.deleteWallpaper(for: conversationID1)
        
        // Assert
        XCTAssertEqual(wallpaperStore.wallpaper(for: conversationID2)?.pngData(), testImage1.pngData())
        XCTAssertEqual(wallpaperStore.wallpaper(for: conversationID1)?.pngData(), testImage1.pngData())
    }
    
    func testDeleteAllCustomWallpaper() {
        // Arrange
        wallpaperStore.saveDefaultWallpaper(testImage1)
        
        // Act
        wallpaperStore.saveWallpaper(testImage2, for: conversationID1)
        wallpaperStore.saveWallpaper(testImage2, for: conversationID2)

        XCTAssertEqual(wallpaperStore.wallpaper(for: conversationID1)?.pngData(), testImage2.pngData())
        XCTAssertEqual(wallpaperStore.wallpaper(for: conversationID2)?.pngData(), testImage2.pngData())

        wallpaperStore.deleteAllCustom()
        
        // Assert
        XCTAssertEqual(wallpaperStore.wallpaper(for: conversationID1)?.pngData(), testImage1.pngData())
        XCTAssertEqual(wallpaperStore.wallpaper(for: conversationID2)?.pngData(), testImage1.pngData())
    }
    
    func testCurrenDefaultWallpaper() {
        // Arrange & Act
        wallpaperStore.saveDefaultWallpaper(testImage1)
        
        // Assert
        XCTAssertEqual(wallpaperStore.currentDefaultWallpaper()?.pngData(), testImage1.pngData())
    }
}
