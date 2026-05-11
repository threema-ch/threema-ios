import Testing
import ThreemaEssentials
import ThreemaProtocols
@testable import ThreemaFramework

@Suite("TaskExecutionReflectWorkSyncDelta Tests")
struct TaskExecutionReflectWorkSyncDeltaTests {

    @Test("Reflect Work Sync delta with no changes")
    func reflectWorkSyncDeltaNoChanges() async throws {
        let sut = sut(reflectMessageResponses: [.lockAck, .unlockAck])

        DDLog.add(sut.ddLoggerMock)

        let task = TaskDefinitionReflectWorkSyncDelta(
            deltas: [CspE2e_WorkSyncDelta.Delta](),
            determineChanges: { _ in
                [D2dSync_Contact]()
            },
            changedManagedObjectID: { _ in
                // no-op
            }
        )

        // Act

        try await task.create(frameworkInjector: sut.businessInjectorMock).execute().async()

        #expect(sut.serverConnectorMock.reflectMessageCalls.count == 2, "Transation messages lock and unlock")
        #expect(
            sut.ddLoggerMock
                .exists(message: "[0x34] sendBeginTransactionToMediator <TaskDefinitionReflectWorkSyncDelta>")
        )
        #expect(sut.ddLoggerMock.exists(message: "No work sync changes to sync"))
        #expect(
            sut.ddLoggerMock
                .exists(message: "[0x61] sendCommitTransactionToMediator <TaskDefinitionReflectWorkSyncDelta>")
        )
        #expect(sut.ddLoggerMock.exists(message: "No changes, we do not persist anything."))

        DDLog.remove(sut.ddLoggerMock)
    }

    @Test("Reflect Work Sync delta without and with existing contact entity", arguments: [false, true])
    func reflectWorkSyncDelta(createContactEntity: Bool) async throws {
        let expectedIdentity = "ECHOECHO"
        let expectedCategory: D2dSync_WorkAvailabilityStatusCategory = .busy
        let expectedDescription = "Holiday"
        var exepctedD2dContactSync = D2dSync_Contact()
        exepctedD2dContactSync.identity = expectedIdentity
        exepctedD2dContactSync.workAvailabilityStatus = .with {
            $0.category = expectedCategory
            $0.description_p = expectedDescription
        }

        let expectedReflectID = BytesUtility.generateReflectID()
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!

        let sut = sut(
            mediatorMessageProtocolMock: MediatorMessageProtocolMock(
                deviceGroupKeys: MockMultiDevice.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock
                        .ReflectData(
                            id: expectedReflectID,
                            message: expectedReflectMessage
                        ),
                ]
            ),
            reflectMessageResponses: [.lockAck, .reflectAck, .unlockAck]
        ) {
            NotificationCenter.default.post(
                name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                object: expectedReflectID,
                userInfo: [expectedReflectID: Date()]
            )
        }

        DDLog.add(sut.ddLoggerMock)

        if createContactEntity {
            sut.testDatabase.backgroundPreparer.save {
                sut.testDatabase.backgroundPreparer.createContact(identity: expectedIdentity)
            }
        }

        let task = TaskDefinitionReflectWorkSyncDelta(
            deltas: [CspE2e_WorkSyncDelta.Delta](),
            determineChanges: { _ in
                [exepctedD2dContactSync]
            },
            changedManagedObjectID: { _ in
                // no-op
            }
        )

        // Act

        try await task.create(frameworkInjector: sut.businessInjectorMock).execute().async()

        #expect(sut.serverConnectorMock.reflectMessageCalls.count == 3, "Transaction messages lock, reflect and unlock")
        #expect(
            sut.ddLoggerMock
                .exists(message: "[0x34] sendBeginTransactionToMediator <TaskDefinitionReflectWorkSyncDelta>")
        )
        #expect(
            sut.ddLoggerMock
                .exists(
                    message: "[0x03] reflectOutgoingMessageToMediator (Reflect ID: \(expectedReflectID.hexString) (unknown multi device message type))"
                )
        )
        #expect(
            sut.ddLoggerMock
                .exists(
                    message: "[0x55] receiveOutgoingMessageAckFromMediator (Reflect ID: \(expectedReflectID.hexString) (unknown multi device message type))"
                )
        )
        #expect(
            sut.ddLoggerMock
                .exists(message: "[0x61] sendCommitTransactionToMediator <TaskDefinitionReflectWorkSyncDelta>")
        )
        if createContactEntity {
            let (category, description) = try await sut.testDatabase.backgroundEntityManager.perform {
                let entity = sut.testDatabase.entityManager.entityFetcher.contactEntity(for: expectedIdentity)
                let workAvailabilityStatus = try #require(entity?.workAvailabilityStatus)
                return (workAvailabilityStatus.value.intValue, workAvailabilityStatus.text)
            }
            #expect(category == expectedCategory.rawValue)
            #expect(description == expectedDescription)
        }
        else {
            #expect(sut.ddLoggerMock.exists(message: "Contact not found for changes. Skipping."))
        }

        DDLog.remove(sut.ddLoggerMock)
    }

    private func sut(
        mediatorMessageProtocolMock: MediatorMessageProtocolMock = MediatorMessageProtocolMock(),
        reflectMessageResponses: [MediatorMessageProtocol.MediatorMessageType],
        reflectMessageAck: (() -> Void)? = nil,
    ) -> (
        testDatabase: TestDatabase,
        ddLoggerMock: DDLoggerMock,
        businessInjectorMock: BusinessInjectorMock,
        serverConnectorMock: ServerConnectorMock,
    ) {
        let ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()

        let testDatabase = TestDatabase()
        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingsMock = UserSettingsMock(enableMultiDevice: true)

        var responses = reflectMessageResponses

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockMultiDevice.deviceID,
            deviceGroupKeys: MockMultiDevice.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                reflectMessageAck?()

                if !responses.isEmpty {
                    let response = responses.removeFirst()
                    if response != .reflect, response != .reflectAck {
                        serverConnectorMock.transactionResponse(response.rawValue, reason: nil)
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
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: mediatorMessageProtocolMock
        )

        return (testDatabase, ddLoggerMock, businessInjectorMock, serverConnectorMock)
    }
}
