import Foundation
import Testing
import ThreemaEssentials

@testable import ThreemaFramework

// The test operates directly on a `mainQueueConcurrencyType` Core Data context (see `DatabaseContextMock`), so the
// whole suite must run on the main thread. Without this, Swift Testing runs the test body on a background cooperative
// thread while the main run loop concurrently processes the context's recent changes, corrupting it and crashing in
// `-[NSManagedObjectContext _postRefreshedObjectsNotificationAndClearList]`.
@MainActor
@Suite("Persistence migration tests")
struct PersistenceMigrationTests {

    @Test("Test migration of the field 'dataAvailable'", arguments: [false, true])
    func migrationOfDataAvailable(encrypted: Bool) throws {
        let testDatabase = TestDatabase(encrypted: encrypted)

        // Get entity and field names
        let fileEntityName = FileMessageEntity.entityName
        let fileFieldName = FileMessageEntity.Field.name(
            for: .dataAvailable,
            encrypted: testDatabase.remoteSecretManagerMock.isRemoteSecretEnabled
        )

        let audioEntityName = AudioMessageEntity.entityName
        let audioFieldName = AudioMessageEntity.Field.name(
            for: .dataAvailable,
            encrypted: testDatabase.remoteSecretManagerMock.isRemoteSecretEnabled
        )

        let imageEntityName = ImageMessageEntity.entityName
        let imageFieldName = ImageMessageEntity.Field.name(
            for: .dataAvailable,
            encrypted: testDatabase.remoteSecretManagerMock.isRemoteSecretEnabled
        )

        let videoEntityName = VideoMessageEntity.entityName
        let videoFieldName = VideoMessageEntity.Field.name(
            for: .dataAvailable,
            encrypted: testDatabase.remoteSecretManagerMock.isRemoteSecretEnabled
        )

        // Setup database after Core Data light weight migration and before data migration
        try setupDataForMigrationOfDataAvailable(
            testDatabase: testDatabase,
            fileEntityName: fileEntityName,
            fileFieldName: fileFieldName,
            audioEntityName: audioEntityName,
            audioFieldName: audioFieldName,
            imageEntityName: imageEntityName,
            imageFieldName: imageFieldName,
            videoEntityName: videoEntityName,
            videoFieldName: videoFieldName
        )

        // Act data mirgation
        let persistenceMigration = PersistenceMigration(entityManager: testDatabase.entityManager)
        try persistenceMigration.migrateDataAvailable(
            remoteSecretEnabled: testDatabase.remoteSecretManagerMock.isRemoteSecretEnabled
        )

        // Reload messages after migration
        let entityManager = testDatabase.entityManager
        let conversation = try #require(entityManager.entityFetcher.conversationEntity(for: "ECHOECHO"))

        // File messages
        let fileMessagesAfterMigration = try #require(entityManager.entityFetcher.fileMessageEntities(for: conversation))
        #expect(!fileMessagesAfterMigration.isEmpty)

        for fileMessage in fileMessagesAfterMigration {
            #expect(fileMessage.dataAvailable.boolValue == (fileMessage.data?.data != nil))
        }

        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: fileEntityName, fieldName: fileFieldName) == 2
        )
        if !testDatabase.remoteSecretManagerMock.isRemoteSecretEnabled {
            try #expect(
                countDataAvailableAreSet(
                    in: testDatabase,
                    entityName: fileEntityName,
                    fieldName: fileFieldName,
                    with: true
                ) == 1
            )
            try #expect(
                countDataAvailableAreSet(
                    in: testDatabase,
                    entityName: fileEntityName,
                    fieldName: fileFieldName,
                    with: false
                ) == 1
            )
        }

        // Audio messages
        let audioMessagesAfterMigration = try #require(
            entityManager.entityFetcher.audioMessageEntities(for: conversation)
        )
        #expect(!audioMessagesAfterMigration.isEmpty)

        for audioMessage in audioMessagesAfterMigration {
            #expect(audioMessage.dataAvailable.boolValue == (audioMessage.audio?.data != nil))
        }

        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: audioEntityName, fieldName: audioFieldName) == 2
        )
        if !testDatabase.remoteSecretManagerMock.isRemoteSecretEnabled {
            try #expect(
                countDataAvailableAreSet(
                    in: testDatabase,
                    entityName: audioEntityName,
                    fieldName: audioFieldName,
                    with: true
                ) == 1
            )
            try #expect(
                countDataAvailableAreSet(
                    in: testDatabase,
                    entityName: audioEntityName,
                    fieldName: audioFieldName,
                    with: false
                ) == 1
            )
        }

        // Image messages
        let imageMessagesAfterMigration = try #require(
            entityManager.entityFetcher.imageMessageEntities(for: conversation)
        )
        #expect(!imageMessagesAfterMigration.isEmpty)

        for imageMessage in imageMessagesAfterMigration {
            #expect(imageMessage.dataAvailable.boolValue == (imageMessage.image?.data != nil))
        }

        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: imageEntityName, fieldName: imageFieldName) == 2
        )
        if !testDatabase.remoteSecretManagerMock.isRemoteSecretEnabled {
            try #expect(
                countDataAvailableAreSet(
                    in: testDatabase,
                    entityName: imageEntityName,
                    fieldName: imageFieldName,
                    with: true
                ) == 1
            )
            try #expect(
                countDataAvailableAreSet(
                    in: testDatabase,
                    entityName: imageEntityName,
                    fieldName: imageFieldName,
                    with: false
                ) == 1
            )
        }

        // Video messages
        let videoMessagesAfterMigration = try #require(
            entityManager.entityFetcher.videoMessageEntities(for: conversation)
        )
        #expect(!videoMessagesAfterMigration.isEmpty)

        for videoMessage in videoMessagesAfterMigration {
            #expect(videoMessage.dataAvailable.boolValue == (videoMessage.video?.data != nil))
        }

        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: videoEntityName, fieldName: videoFieldName) == 2
        )
        if !testDatabase.remoteSecretManagerMock.isRemoteSecretEnabled {
            try #expect(
                countDataAvailableAreSet(
                    in: testDatabase,
                    entityName: imageEntityName,
                    fieldName: videoFieldName,
                    with: true
                ) == 1
            )
            try #expect(
                countDataAvailableAreSet(
                    in: testDatabase,
                    entityName: imageEntityName,
                    fieldName: videoFieldName,
                    with: false
                ) == 1
            )
        }
    }

    /// Setup database right after ligth weight migration, no `dataAvailable` fields are set!
    private func setupDataForMigrationOfDataAvailable(
        testDatabase: TestDatabase,
        fileEntityName: String,
        fileFieldName: String,
        audioEntityName: String,
        audioFieldName: String,
        imageEntityName: String,
        imageFieldName: String,
        videoEntityName: String,
        videoFieldName: String,
    ) throws {
        let dbPreparer = testDatabase.preparer

        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO"
            )

            let addFileMessages: (ConversationEntity, Bool) -> Void = {
                conversation,
                withData in

                if withData {
                    let fileData = dbPreparer.createFileDataEntity(data: Data(count: 32))
                    dbPreparer.createFileMessageEntity(conversation: conversation, data: fileData)

                    let audioData = dbPreparer.createAudioDataEntity(data: Data(count: 32))
                    dbPreparer.createAudioMessageEntity(
                        conversation: conversation,
                        audio: audioData,
                        duration: 1.0,
                        complete: nil
                    )

                    let imageData = dbPreparer.createImageDataEntity(data: Data(count: 32), height: 10, width: 10)
                    dbPreparer.createImageMessageEntity(
                        conversation: conversation,
                        image: imageData,
                        thumbnail: imageData,
                        isOwn: true,
                        sender: nil,
                        remoteSentDate: nil
                    )

                    let videoData = dbPreparer.createVideoDataEntity(data: Data(count: 32))
                    dbPreparer.createVideoMessageEntity(
                        conversation: conversation,
                        video: videoData,
                        duration: 1,
                        thumbnail: nil,
                        isOwn: true,
                        sender: nil,
                        remoteSentDate: nil
                    )
                }
                else {
                    dbPreparer.createFileMessageEntity(conversation: conversation)

                    dbPreparer.createAudioMessageEntity(
                        conversation: conversation,
                        duration: 1.0,
                        complete: nil
                    )

                    dbPreparer.createImageMessageEntity(
                        conversation: conversation,
                        image: nil,
                        thumbnail: nil,
                        isOwn: true,
                        sender: nil,
                        remoteSentDate: nil
                    )

                    dbPreparer.createVideoMessageEntity(
                        conversation: conversation,
                        video: nil,
                        duration: 1,
                        thumbnail: nil,
                        isOwn: true,
                        sender: nil,
                        remoteSentDate: nil
                    )
                }
            }

            dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.contact = contact
                    addFileMessages(conversation, true)
                    addFileMessages(conversation, false)
                }
        }

        // Reset all `dataAvailable` fields
        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: fileEntityName, fieldName: fileFieldName) == 2
        )
        try nullifyDataAvailable(in: testDatabase, entityName: fileEntityName, fieldName: fileFieldName)

        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: audioEntityName, fieldName: audioFieldName) == 2
        )
        try nullifyDataAvailable(in: testDatabase, entityName: audioEntityName, fieldName: audioFieldName)

        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: imageEntityName, fieldName: imageFieldName) == 2
        )
        try nullifyDataAvailable(in: testDatabase, entityName: imageEntityName, fieldName: imageFieldName)

        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: videoEntityName, fieldName: videoFieldName) == 2
        )
        try nullifyDataAvailable(in: testDatabase, entityName: videoEntityName, fieldName: videoFieldName)

        // Check no `dataAvailble`fields are set after reset
        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: fileEntityName, fieldName: fileFieldName) == 0
        )
        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: audioEntityName, fieldName: audioFieldName) == 0
        )
        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: imageEntityName, fieldName: imageFieldName) == 0
        )
        try #expect(
            countDataAvailableAreSet(in: testDatabase, entityName: videoEntityName, fieldName: videoFieldName) == 0
        )

        try #expect(testDatabase.entityManager.entityFetcher.fileMessageObjectIDsWithDataAvailable().count == 1)

        // Reset DB contexts after preparing with bath updates
        testDatabase.context.current.refreshAllObjects()
    }

    private func nullifyDataAvailable(in testDatabase: TestDatabase, entityName: String, fieldName: String) throws {
        // Set all `dataAvailable` fields to nil
        let batchUpdate1 = NSBatchUpdateRequest(entityName: entityName)
        batchUpdate1.propertiesToUpdate = [fieldName: NSExpression(forConstantValue: nil)]
        try testDatabase.context.current.execute(batchUpdate1)

        if testDatabase.remoteSecretManagerMock.isRemoteSecretEnabled {
            let batchUpdate2 = NSBatchUpdateRequest(entityName: entityName)
            batchUpdate2.propertiesToUpdate = [fieldName: NSExpression(forConstantValue: nil)]
            try testDatabase.context.current.execute(batchUpdate2)
        }
    }

    private func countDataAvailableAreSet(
        in testDatabase: TestDatabase,
        entityName: String,
        fieldName: String,
        with value: Bool? = nil
    ) throws -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        if let value {
            fetchRequest.predicate = NSPredicate(format: "\(fieldName) != %i", value ? 1 : 0)
        }
        else {
            fetchRequest.predicate = NSPredicate(format: "\(fieldName) != nil")
        }
        fetchRequest.resultType = .countResultType

        let result = try testDatabase.context.current.fetch(fetchRequest)
        return result.first as? Int ?? -1
    }
}
