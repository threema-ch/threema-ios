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

import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

final class TaskExecutionUpdateContactSyncTests: XCTestCase {

    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)
    }

    func testSyncContactWithImageUploadAndNoneUpload() throws {
        let expectedReflectID = MockData.generateReflectID()
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
            c1.contactImage = dbPreparer.createImageData(data: contactImage, height: 1, width: 1)
            let c2 = dbPreparer.createContact(identity: "TESTER02")
            c2.contactImage = dbPreparer.createImageData(data: contactImage, height: 1, width: 1)
        }

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
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
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
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
            blobUploader: BlobUploaderMock(blobIDs: [MockData.generateBlobID()])
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
        dsc2.contactImageBlobID = MockData.generateBlobID()
        dsc2.contactImageEncryptionKey = MockData.generateBlobEncryptionKey()

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
