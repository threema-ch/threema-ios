//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

class FileMessageEntityRenderTypeTests: XCTestCase {
    
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
        
    func testFileMessageImageRenderedAsFile() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "image/jpeg"
            fileMessageEntity.type = 0
        }

        XCTAssertEqual(.fileMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageImageRenderedAsImage() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "image/jpg"
            fileMessageEntity.type = 1
        }

        XCTAssertEqual(.imageMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageImageRenderedAsSticker() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "image/png"
            fileMessageEntity.type = 2
        }

        XCTAssertEqual(.stickerMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageAnimatedRenderedAsFile() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "image/gif"
            fileMessageEntity.type = 0
        }

        XCTAssertEqual(.fileMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageAnimatedRenderedAsAnimatedImage() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "image/gif"
            fileMessageEntity.type = 1
        }

        XCTAssertEqual(.animatedImageMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageAnimatedRenderedAsAnimatedSticker() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "image/gif"
            fileMessageEntity.type = 2
        }

        XCTAssertEqual(.animatedStickerMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageVideoRenderedAsFile() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "video/mpeg4"
            fileMessageEntity.type = 0
        }

        XCTAssertEqual(.fileMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageVideoRenderedAsVideo1() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "video/mp4"
            fileMessageEntity.type = 1
        }

        XCTAssertEqual(.videoMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageVideoRenderedAsVideo2() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "video/x-m4v"
            fileMessageEntity.type = 2
        }

        XCTAssertEqual(.videoMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageAudioRenderedAsFile() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "audio/mp4"
            fileMessageEntity.type = 0
        }

        XCTAssertEqual(.fileMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageAudioRenderedAsVoice1() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "audio/aac"
            fileMessageEntity.type = 1
        }

        XCTAssertEqual(.voiceMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageAudioRenderedAsVoice2() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "audio/m4a"
            fileMessageEntity.type = 2
        }

        XCTAssertEqual(.voiceMessage, fileMessageEntity.renderType)
    }
    
    func testFileMessageFileRenderedAsFile() {
        var fileMessageEntity: FileMessageEntity!

        databasePreparer.save {
            fileMessageEntity = databasePreparer.createFileMessageEntity(conversation: conversation)
            fileMessageEntity.mimeType = "application/pdf"
        }

        XCTAssertEqual(.fileMessage, fileMessageEntity.renderType)
    }
}
