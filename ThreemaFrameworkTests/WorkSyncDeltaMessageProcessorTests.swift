import Testing
import ThreemaProtocols
@testable import ThreemaFramework

@Suite("WorkSyncDeltaMessageProcessor Tests")
struct WorkSyncDeltaMessageProcessorTests {

    @Test("Incoming WorkSyncDeltaMessage for work contact", arguments: [
        Date.now,
        Date.now.addingTimeInterval(10),
        Date.now.addingTimeInterval(-10),
    ])
    func handleWorkSyncDeltaForWorkContact(appliedAt: Date) async throws {
        let sut = sut()

        let expectedIdentity = "ECHOECHO"
        let expectedWorkLastSyncAt = Date.now.addingTimeInterval(-1)
        let expectedAvailabilityStatus: D2dSync_WorkAvailabilityStatusCategory = .unavailable
        let expectedAvailabilityDescription = "Holiday"

        sut.testDatabase.backgroundPreparer.save {
            let entity = sut.testDatabase.backgroundPreparer.createContact(identity: expectedIdentity)
            entity.workContact = true
            entity.workLastFullSyncAt = expectedWorkLastSyncAt
        }

        let message = messageWithDeltaApply(
            identity: expectedIdentity,
            availabilityStatusCategory: expectedAvailabilityStatus,
            availabilityDescription: expectedAvailabilityDescription,
            appliedAt: appliedAt.millisecondsSince1970
        )

        if expectedWorkLastSyncAt >= appliedAt {
            try await sut.workSyncDeltaMessageProcessor.handle(message: message)

            #expect(
                sut.testDatabase.entityManager.entityFetcher
                    .contactEntity(for: expectedIdentity)?.workAvailabilityStatus == nil
            )
        }
        else {
            try await sut.workSyncDeltaMessageProcessor.handle(message: message)

            let availabilityStatus = try #require(
                sut.testDatabase.entityManager.entityFetcher
                    .contactEntity(for: expectedIdentity)?.workAvailabilityStatus
            )

            #expect(availabilityStatus.value.intValue == expectedAvailabilityStatus.rawValue)
            #expect(availabilityStatus.text == expectedAvailabilityDescription)
        }

        #expect(sut.taskManagerMock.addedTasks.isEmpty)
        #expect(sut.taskManagerMock.executeSubTaskCalls.isEmpty)
    }

    @Test("Incoming WorkSyncDeltaMessage for work contact with MD enabled")
    func handleWorkSyncDeltaForWorkContactWithEnableMultiDevice() async throws {
        let sut = sut(enableMultiDevice: true)

        let expectedIdentity = "ECHOECHO"
        let expectedAvailabilityStatusCategory: D2dSync_WorkAvailabilityStatusCategory = .unavailable
        let expectedAvailabilityDescription = "Holiday"

        sut.testDatabase.backgroundPreparer.save {
            let entity = sut.testDatabase.backgroundPreparer.createContact(identity: expectedIdentity)
            entity.workContact = true
        }

        let message = messageWithDeltaApply(
            identity: expectedIdentity,
            availabilityStatusCategory: expectedAvailabilityStatusCategory,
            availabilityDescription: expectedAvailabilityDescription
        )

        try await sut.workSyncDeltaMessageProcessor.handle(message: message)

        #expect(sut.taskManagerMock.addedTasks.isEmpty)
        #expect(sut.taskManagerMock.executeSubTaskCalls.count == 1)
        let subTask = try #require(sut.taskManagerMock.executeSubTaskCalls.first as? TaskDefinitionReflectWorkSyncDelta)
        #expect(subTask.deltas.contains(where: {
            $0.contactSync.update.identity == expectedIdentity &&
                $0.contactSync.update.availabilityStatus.category == expectedAvailabilityStatusCategory &&
                $0.contactSync.update.availabilityStatus.description_p == expectedAvailabilityDescription
        }))
    }

    @Test("Incoming WorkSyncDeltaMessage for none work contact", arguments: [
        AppGroupTypeApp,
        AppGroupTypeNotificationExtension,
        AppGroupTypeShareExtension,
        AppGroupTypeNone,
    ])
    func handleWorkSyncDeltaForNoneWorkContact(appGroupType: AppGroupType) async throws {
        let sut = sut(appGroupType: appGroupType)

        let expectedIdentity = "ECHOECHO"
        let expectedAvailabilityStatusCategory: D2dSync_WorkAvailabilityStatusCategory = .unavailable
        let expectedAvailabilityDescription = "Holiday"

        sut.testDatabase.backgroundPreparer.save {
            sut.testDatabase.backgroundPreparer.createContact(identity: expectedIdentity)
        }

        let message = messageWithDeltaApply(
            identity: expectedIdentity,
            availabilityStatusCategory: expectedAvailabilityStatusCategory,
            availabilityDescription: expectedAvailabilityDescription
        )

        try await sut.workSyncDeltaMessageProcessor.handle(message: message)

        if appGroupType == AppGroupTypeApp {
            #expect(sut.workDataFetcherMock.checkUpdateWorkData.count(where: { $0.force && !$0.forceSendMDM }) == 1)
            #expect(sut.workDataFetcherMock.resetLastSyncCount == 0)
        }
        else {
            #expect(sut.workDataFetcherMock.checkUpdateWorkData.isEmpty)
            #expect(sut.workDataFetcherMock.resetLastSyncCount == 1)
        }

        #expect(sut.taskManagerMock.addedTasks.isEmpty)
        #expect(sut.taskManagerMock.executeSubTaskCalls.isEmpty)
    }

    @Test("Incoming WorkSyncDeltaMessage contact not found")
    func handleWorkSyncDeltaContactNotFound() async throws {
        let sut = sut()

        let expectedIdentity = "ECHOECHO"
        let expectedAvailabilityStatusCategory: D2dSync_WorkAvailabilityStatusCategory = .unavailable
        let expectedAvailabilityDescription = "Holiday"

        let message = messageWithDeltaApply(
            identity: expectedIdentity,
            availabilityStatusCategory: expectedAvailabilityStatusCategory,
            availabilityDescription: expectedAvailabilityDescription
        )

        try await sut.workSyncDeltaMessageProcessor.handle(message: message)

        #expect(sut.taskManagerMock.addedTasks.isEmpty)
        #expect(sut.taskManagerMock.executeSubTaskCalls.isEmpty)
    }

    @Test("Incoming WorkSyncDeltaMessage require work sync", arguments: [
        AppGroupTypeApp,
        AppGroupTypeNotificationExtension,
        AppGroupTypeShareExtension,
        AppGroupTypeNone,
    ])
    func handleWorkSyncDeltaWithRequireWorkSync(appGroupType: AppGroupType) async throws {
        let sut = sut(appGroupType: appGroupType)

        let expectedIdentity = "ECHOECHO"

        let message = messageWithDeltaRequireWorkSync(identity: expectedIdentity)

        try await sut.workSyncDeltaMessageProcessor.handle(message: message)

        if appGroupType == AppGroupTypeApp {
            #expect(sut.workDataFetcherMock.checkUpdateWorkData.count(where: { $0.force && !$0.forceSendMDM }) == 1)
            #expect(sut.workDataFetcherMock.resetLastSyncCount == 0)
        }
        else {
            #expect(sut.workDataFetcherMock.checkUpdateWorkData.isEmpty)
            #expect(sut.workDataFetcherMock.resetLastSyncCount == 1)
        }

        #expect(sut.taskManagerMock.addedTasks.isEmpty)
        #expect(sut.taskManagerMock.executeSubTaskCalls.isEmpty)
    }

    private func messageWithDeltaRequireWorkSync(identity: String) -> WorkSyncDeltaMessage {
        var delta = CspE2e_WorkSyncDelta()
        delta.action = .requireWorkSync(Common_Unit())
        return message(for: identity, with: delta)
    }

    private func messageWithDeltaApply(
        identity: String,
        availabilityStatusCategory: D2dSync_WorkAvailabilityStatusCategory,
        availabilityDescription: String,
        appliedAt: UInt64 = Date.now.millisecondsSince1970
    ) -> WorkSyncDeltaMessage {
        var delta = CspE2e_WorkSyncDelta()
        delta.action = .apply(
            .with {
                $0.deltas = [
                    .with {
                        $0.appliedAt = appliedAt
                        $0.action = .contactSync(.with {
                            $0.update = .with {
                                $0.identity = identity
                                $0.availabilityStatus = .with {
                                    $0.category = availabilityStatusCategory
                                    $0.description_p = availabilityDescription
                                }
                            }
                        })
                    },
                ]
            }
        )
        return message(for: identity, with: delta)
    }

    private func message(for identity: String, with delta: CspE2e_WorkSyncDelta) -> WorkSyncDeltaMessage {
        let message = WorkSyncDeltaMessage()
        message.fromIdentity = "*3MAW0RK"
        message.toIdentity = identity
        message.decoded = delta
        return message
    }

    private func sut(appGroupType: AppGroupType = AppGroupTypeApp, enableMultiDevice: Bool = false) -> (
        testDatabase: TestDatabase,
        userSettingsMock: UserSettingsMock,
        taskManagerMock: TaskManagerMock,
        workDataFetcherMock: WorkDataFetcherMock,
        workSyncDeltaMessageProcessor: WorkSyncDeltaMessageProcessor
    ) {
        let testDatabase = TestDatabase()
        let userSettingsMock = UserSettingsMock(enableMultiDevice: enableMultiDevice)
        let taskManagerMock = TaskManagerMock()
        let workDataFetcherMock = WorkDataFetcherMock()

        let workSyncDeltaMessageProcessor = WorkSyncDeltaMessageProcessor(
            appGroupType: appGroupType,
            entityManager: testDatabase.backgroundEntityManager,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            userSettings: userSettingsMock,
            taskManager: taskManagerMock,
            workDataFetcher: workDataFetcherMock
        )

        return (
            testDatabase,
            userSettingsMock,
            taskManagerMock,
            workDataFetcherMock,
            workSyncDeltaMessageProcessor
        )
    }
}
