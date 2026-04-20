import XCTest
@testable import ThreemaFramework

final class FileMessageEntityRenderTypeTests: XCTestCase {
    
    private var databasePreparer: TestDatabasePreparer!
    private var conversation: ConversationEntity!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        let testDatabase = TestDatabase()
        databasePreparer = testDatabase.preparer
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
