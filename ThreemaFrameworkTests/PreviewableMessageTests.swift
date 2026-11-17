import Foundation
import Testing
import ThreemaMacros

@testable import ThreemaFramework

// The tests operate directly on a `mainQueueConcurrencyType` Core Data context (see `DatabaseContextMock`), so the
// whole suite must run on the main thread. See `PersistenceMigrationTests` for the full reasoning.
@MainActor
@Suite("Previewable message tests")
struct PreviewableMessageTests {

    // MARK: - Text

    @Test("Text message previews its text")
    func textMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            dbPreparer.createTextMessage(
                conversation: dbPreparer.createConversation(),
                text: "Probably a long msg",
                isOwn: false,
                sender: nil,
                remoteSentDate: .now
            )
        }

        #expect(message.previewText == "Probably a long msg")
    }

    @Test("Deleted message previews the deleted text instead of its content")
    func deletedMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            let message = dbPreparer.createTextMessage(
                conversation: dbPreparer.createConversation(),
                text: "Probably a long msg",
                isOwn: false,
                sender: nil,
                remoteSentDate: .now
            )
            message.deletedAt = .now
            return message
        }

        #expect(message.previewText == #localize("deleted_message"))
    }

    // MARK: - Media

    @Test(
        "Image message previews its caption, or the type if it has none",
        arguments: [nil, "Image caption"] as [String?]
    )
    func imageFileMessage(caption: String?) {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            dbPreparer.createFileMessageEntity(
                conversation: dbPreparer.createConversation(),
                mimeType: "image/jpeg",
                type: 1,
                caption: caption
            )
        }

        #expect(message.renderType == .imageMessage)
        #expect(message.previewText == (caption ?? message.fileMessageType.localizedDescription))
    }

    @Test("Legacy image message previews the type, it cannot have a caption")
    func legacyImageMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            dbPreparer.createImageMessageEntity(
                conversation: dbPreparer.createConversation(),
                image: nil,
                thumbnail: nil,
                isOwn: false,
                sender: nil,
                remoteSentDate: .now
            )
        }

        #expect(message.previewText == message.fileMessageType.localizedDescription)
    }

    @Test("Legacy video message previews the type, it cannot have a caption")
    func legacyVideoMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            dbPreparer.createVideoMessageEntity(
                conversation: dbPreparer.createConversation(),
                video: nil,
                duration: 12,
                thumbnail: nil,
                isOwn: false,
                sender: nil,
                remoteSentDate: .now
            )
        }

        #expect(message.previewText == message.fileMessageType.localizedDescription)
    }

    @Test("Audio message previews its type and duration")
    func audioMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            dbPreparer.createAudioMessageEntity(
                conversation: dbPreparer.createConversation(),
                duration: 7,
                complete: nil
            )
        }

        let expectedDuration = DateFormatter.timeFormatted(7)
        #expect(message.previewText == "\(message.fileMessageType.localizedDescription) (\(expectedDuration))")
    }

    // MARK: - File

    @Test(
        "File message previews its caption, or the file name if it has none",
        arguments: [nil, "File caption"] as [String?]
    )
    func fileMessage(caption: String?) {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            let message = dbPreparer.createFileMessageEntity(
                conversation: dbPreparer.createConversation(),
                mimeType: "application/pdf",
                type: 0,
                caption: caption
            )
            message.fileName = "contract.pdf"
            return message
        }

        #expect(message.renderType == .fileMessage)
        #expect(message.previewText == (caption ?? "contract.pdf"))
    }

    @Test("Voice message previews its type and duration")
    func voiceMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            dbPreparer.createFileMessageEntity(
                conversation: dbPreparer.createConversation(),
                mimeType: "audio/aac",
                type: 1
            )
        }

        #expect(message.renderType == .voiceMessage)

        let expectedDuration = DateFormatter.timeFormatted(Int(message.durationTimeInterval ?? 0))
        #expect(message.previewText == "\(message.fileMessageType.localizedDescription) (\(expectedDuration))")
    }

    // MARK: - Location

    @Test("Location message previews its name, then its address, then the type")
    func locationMessage() {
        let dbPreparer = TestDatabase().preparer

        let withName = dbPreparer.save {
            dbPreparer.createLocationMessage(
                conversation: dbPreparer.createConversation(),
                accuracy: 1,
                latitude: 47.201_515,
                longitude: 8.784_484,
                poiAddress: "Example street 1",
                poiName: "Example place",
                isOwn: false
            )
        }
        let withAddress = dbPreparer.save {
            dbPreparer.createLocationMessage(
                conversation: dbPreparer.createConversation(),
                accuracy: 1,
                latitude: 47.201_515,
                longitude: 8.784_484,
                poiAddress: "Example street 1",
                poiName: nil,
                isOwn: false
            )
        }
        let withNeither = dbPreparer.save {
            dbPreparer.createLocationMessage(
                conversation: dbPreparer.createConversation(),
                accuracy: 1,
                latitude: 47.201_515,
                longitude: 8.784_484,
                poiName: nil,
                isOwn: false
            )
        }

        #expect(withName.previewText == "Example place")
        #expect(withAddress.previewText == "Example street 1")
        #expect(withNeither.previewText == #localize("location"))
    }

    // MARK: - Ballot

    @Test("Ballot message previews the ballot title")
    func ballotMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            let conversation = dbPreparer.createConversation()
            let ballot = dbPreparer.createBallot(conversation: conversation)
            ballot.title = "Lunch place"
            return dbPreparer.createBallotMessage(
                conversation: conversation,
                ballot: ballot,
                isOwn: false
            )
        }

        #expect(message.previewText == "Lunch place")
    }

    // MARK: - Quoted preview

    @Test("Text message is quoted as a whole")
    func quotedTextMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            dbPreparer.createTextMessage(
                conversation: dbPreparer.createConversation(),
                text: "Probably a long msg",
                isOwn: false,
                sender: nil,
                remoteSentDate: .now
            )
        }

        #expect(message.previewDescription.typeName == nil)
        #expect(message.previewDescription.quotedText == "Probably a long msg")
        #expect(message.quotedPreviewText() == "\"Probably a long msg\"")
    }

    @Test("Markup is removed from the quoted text and long text is trimmed")
    func quotedTextMessageIsParsedAndTrimmed() {
        let dbPreparer = TestDatabase().preparer
        let boldMessage = dbPreparer.save {
            dbPreparer.createTextMessage(
                conversation: dbPreparer.createConversation(),
                text: "*Shout*",
                isOwn: false,
                sender: nil,
                remoteSentDate: .now
            )
        }
        let longMessage = dbPreparer.save {
            dbPreparer.createTextMessage(
                conversation: dbPreparer.createConversation(),
                text: String(repeating: "a", count: 500),
                isOwn: false,
                sender: nil,
                remoteSentDate: .now
            )
        }

        #expect(boldMessage.quotedPreviewText() == "\"Shout\"")

        let trimmingCount = PreviewableMessageConfiguration.pushNotification.trimmingCount
        // The two quotes are not part of the message text
        #expect(longMessage.quotedPreviewText(for: .pushNotification)?.count == trimmingCount + 2)
    }

    @Test("Media without a caption is quoted by its type only", arguments: [nil, "Image caption"] as [String?])
    func quotedImageFileMessage(caption: String?) {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            dbPreparer.createFileMessageEntity(
                conversation: dbPreparer.createConversation(),
                mimeType: "image/jpeg",
                type: 1,
                caption: caption
            )
        }

        if let caption {
            #expect(message.previewDescription.typeName == nil)
            #expect(message.quotedPreviewText() == "\"\(caption)\"")
        }
        else {
            // e.g. `Image`, without quotes and without a name
            #expect(message.previewDescription.quotedText == nil)
            #expect(message.quotedPreviewText() == message.fileMessageType.localizedDescription)
        }
    }

    @Test("File message is quoted by its type and its name", arguments: [nil, "File caption"] as [String?])
    func quotedFileMessage(caption: String?) {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            let message = dbPreparer.createFileMessageEntity(
                conversation: dbPreparer.createConversation(),
                mimeType: "application/pdf",
                type: 0,
                caption: caption
            )
            message.fileName = "contract.pdf"
            return message
        }

        // e.g. `File "contract.pdf"`
        let expectedName = caption ?? "contract.pdf"
        #expect(message.quotedPreviewText() == "\(#localize("file_message_file")) \"\(expectedName)\"")
    }

    @Test("Voice message is quoted by its type and duration, without quotes")
    func quotedVoiceMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            dbPreparer.createFileMessageEntity(
                conversation: dbPreparer.createConversation(),
                mimeType: "audio/aac",
                type: 1
            )
        }

        #expect(message.previewDescription.quotedText == nil)
        #expect(message.quotedPreviewText() == message.previewText)
    }

    @Test("Location message is quoted by its type and name")
    func quotedLocationMessage() {
        let dbPreparer = TestDatabase().preparer

        let withName = dbPreparer.save {
            dbPreparer.createLocationMessage(
                conversation: dbPreparer.createConversation(),
                accuracy: 1,
                latitude: 47.201_515,
                longitude: 8.784_484,
                poiName: "Example place",
                isOwn: false
            )
        }
        let withNeither = dbPreparer.save {
            dbPreparer.createLocationMessage(
                conversation: dbPreparer.createConversation(),
                accuracy: 1,
                latitude: 47.201_515,
                longitude: 8.784_484,
                poiName: nil,
                isOwn: false
            )
        }

        #expect(withName.quotedPreviewText() == "\(#localize("location")) \"Example place\"")
        #expect(withNeither.quotedPreviewText() == #localize("location"))
    }

    @Test("Ballot message is quoted by its type and title")
    func quotedBallotMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            let conversation = dbPreparer.createConversation()
            let ballot = dbPreparer.createBallot(conversation: conversation)
            ballot.title = "Lunch place"
            return dbPreparer.createBallotMessage(
                conversation: conversation,
                ballot: ballot,
                isOwn: false
            )
        }

        #expect(message.quotedPreviewText() == "\(#localize("ballot")) \"Lunch place\"")
    }

    @Test("Deleted message is quoted by the deleted text, without quotes")
    func quotedDeletedMessage() {
        let dbPreparer = TestDatabase().preparer
        let message = dbPreparer.save {
            let message = dbPreparer.createFileMessageEntity(
                conversation: dbPreparer.createConversation(),
                mimeType: "image/jpeg",
                type: 1,
                caption: "Image caption"
            )
            message.deletedAt = .now
            return message
        }

        #expect(message.quotedPreviewText() == #localize("deleted_message"))
    }
}
