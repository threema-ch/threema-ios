import ThreemaEssentials

import ThreemaProtocols
import XCTest

@testable import ThreemaFramework

final class TaskExecutionUpdateContactSyncTests: XCTestCase {

    private var testDatabase: TestDatabase!
    private var dbPreparer: TestDatabasePreparer!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
        dbPreparer = testDatabase.backgroundPreparer
    }

    func testSyncContactWithImageUploadAndNoneUpload() throws {
        let expectedReflectID = BytesUtility.generateReflectID()
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 24)!
        let contactImage = BytesUtility.generateRandomBytes(length: 10)!

        var transactionScope = D2d_TransactionScope.Scope.contactSync
        let transactionScopeData = Data(bytes: &transactionScope, count: MemoryLayout.size(ofValue: transactionScope))

        var mediatorResponseMessageType: [MediatorMessageProtocol.MediatorMessageType] =
            [
                MediatorMessageProtocol.MediatorMessageType.lockAck,
                MediatorMessageProtocol.MediatorMessageType.reflectAck,
                MediatorMessageProtocol.MediatorMessageType.reflectAck,
                MediatorMessageProtocol.MediatorMessageType.unlockAck,
            ]

        dbPreparer.save {
            let c1 = dbPreparer.createContact(identity: "TESTER01")
            c1.contactImage = dbPreparer.createImageDataEntity(data: contactImage, height: 1, width: 1)
            let c2 = dbPreparer.createContact(identity: "TESTER02")
            c2.contactImage = dbPreparer.createImageDataEntity(data: contactImage, height: 1, width: 1)
        }

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockMultiDevice.deviceID,
            deviceGroupKeys: MockMultiDevice.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: Date()]
                )

                if !mediatorResponseMessageType.isEmpty {
                    let response = mediatorResponseMessageType.removeFirst()
                    if response != .reflectAck {
                        serverConnectorMock.transactionResponse(
                            response.rawValue,
                            reason: transactionScopeData
                        )
                    }
                }
                return nil
            }
            return ThreemaError.threemaError(
                "Not logged in",
                withCode: ThreemaProtocolError.notLoggedIn.rawValue
            ) as? NSError
        }

        let businessInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.backgroundEntityManager,
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockMultiDevice.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock
                        .ReflectData(
                            id: expectedReflectID,
                            message: expectedReflectMessage
                        ),
                    MediatorMessageProtocolMock
                        .ReflectData(
                            id: expectedReflectID,
                            message: expectedReflectMessage
                        ),
                ]
            ),
            blobUploader: BlobUploaderMock(blobIDs: [BytesUtility.generateBlobID()])
        )

        var sc1 = Sync_Contact()
        sc1.identity = "TESTER01"
        var dsc1 = DeltaSyncContact(
            syncContact: sc1,
            syncAction: .update
        )
        dsc1.contactProfilePicture = .updated
        dsc1.contactImage = contactImage

        var sc2 = Sync_Contact()
        sc2.identity = "TESTER02"
        var dsc2 = DeltaSyncContact(
            syncContact: sc2,
            syncAction: .update
        )
        dsc2.contactProfilePicture = .updated
        dsc2.contactImage = contactImage
        dsc2.contactImageBlobID = BytesUtility.generateBlobID()
        dsc2.contactImageEncryptionKey = BytesUtility.generateBlobEncryptionKey()

        var deltaSyncContacts = [DeltaSyncContact]()
        deltaSyncContacts.append(dsc1)
        deltaSyncContacts.append(dsc2)

        let expect = expectation(description: "Task execution")

        let task = TaskDefinitionUpdateContactSync(deltaSyncContacts: deltaSyncContacts)
        task.create(frameworkInjector: businessInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                XCTFail("\(error)")
            }

        wait(for: [expect])

        XCTAssertEqual(4, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertTrue(serverConnectorMock.sendMessageCalls.isEmpty)
    }
}
