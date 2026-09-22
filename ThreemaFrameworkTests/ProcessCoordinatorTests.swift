import CocoaLumberjackSwift
import Testing
import ThreemaEssentials
@testable import ThreemaFramework

final class ProcessCoordinatorTests {

    private var ddLoggerMock: DDLoggerMock!

    init() async throws {
        self.ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    deinit {
        DDLog.remove(ddLoggerMock)
    }

    struct TestCaseAccessState {
        let receivedState: ProcessCoordinator.AccessState
        let fromAppType: AppGroupType
        let myState: ProcessCoordinator.AccessState
        let myAppType: AppGroupType
        let newState: ProcessCoordinator.AccessState
        var disconnectBy: ConnectionInitiator?
    }

    @Test("Test received state from my own app")
    func testReceivedStateFromMyOwnApp() throws {
        let expectedReceivedState: ProcessCoordinator.AccessState = .using
        let expectedLogMessage =
            "[Darwin] Received state '\(expectedReceivedState)' from self app '\(AppGroup.name(for: AppGroupTypeApp))'"

        let processCoordinator = ProcessCoordinator(
            myAppType: AppGroupTypeApp,
            state: .requested,
            serverConnector: ServerConnectorMock(),
            userSettings: UserSettingsMock()
        )

        let result = processCoordinator.testProcess(state: expectedReceivedState, from: AppGroupTypeApp)
        #expect(result == .requested)

        try #require(ddLoggerMock.exists(message: expectedLogMessage))
    }

    @Test(
        "Test received state in all combinations",
        arguments: [
            // 1.1 Tests cases: Sender is App / Receiver is Share Extension
            // 1.1.1 Received state `unused`
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeApp,
                myState: .unused,
                myAppType: AppGroupTypeShareExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeApp,
                myState: .using,
                myAppType: AppGroupTypeShareExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeApp,
                myState: .requested,
                myAppType: AppGroupTypeShareExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeApp,
                myState: .willRelease,
                myAppType: AppGroupTypeShareExtension,
                newState: .willRelease
            ),

            // 1.1.2 Received state `using`
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeApp,
                myState: .unused,
                myAppType: AppGroupTypeShareExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeApp,
                myState: .using,
                myAppType: AppGroupTypeShareExtension,
                newState: .willRelease,
                disconnectBy: .shareExtension
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeApp,
                myState: .requested,
                myAppType: AppGroupTypeShareExtension,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeApp,
                myState: .willRelease,
                myAppType: AppGroupTypeShareExtension,
                newState: .willRelease,
                disconnectBy: .shareExtension
            ),

            // 1.1.3 Received state `requested`
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeApp,
                myState: .unused,
                myAppType: AppGroupTypeShareExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeApp,
                myState: .using,
                myAppType: AppGroupTypeShareExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeApp,
                myState: .requested,
                myAppType: AppGroupTypeShareExtension,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeApp,
                myState: .willRelease,
                myAppType: AppGroupTypeShareExtension,
                newState: .willRelease
            ),

            // 1.1.4 Received state `willRelease`
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeApp,
                myState: .unused,
                myAppType: AppGroupTypeShareExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeApp,
                myState: .using,
                myAppType: AppGroupTypeShareExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeApp,
                myState: .requested,
                myAppType: AppGroupTypeShareExtension,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeApp,
                myState: .willRelease,
                myAppType: AppGroupTypeShareExtension,
                newState: .willRelease
            ),

            // 1.2 Tests cases: Sender is App / Receiver is Notification Extension
            // 1.2.1 Received state `unused`
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeApp,
                myState: .unused,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeApp,
                myState: .using,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeApp,
                myState: .requested,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeApp,
                myState: .willRelease,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),

            // 1.2.2 Received state `using`
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeApp,
                myState: .unused,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeApp,
                myState: .using,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease,
                disconnectBy: .notificationExtension
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeApp,
                myState: .requested,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeApp,
                myState: .willRelease,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease,
                disconnectBy: .notificationExtension
            ),

            // 1.2.3 Received state `requested`
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeApp,
                myState: .unused,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeApp,
                myState: .using,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeApp,
                myState: .requested,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeApp,
                myState: .willRelease,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),

            // 1.2.4 Received state `willRelease`
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeApp,
                myState: .unused,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeApp,
                myState: .using,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeApp,
                myState: .requested,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeApp,
                myState: .willRelease,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),

            // 2.1 Tests cases: Sender is Share Extension / Receiver is App
            // 2.1.1 Received state `unused`
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeShareExtension,
                myState: .unused,
                myAppType: AppGroupTypeApp,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeShareExtension,
                myState: .using,
                myAppType: AppGroupTypeApp,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeShareExtension,
                myState: .requested,
                myAppType: AppGroupTypeApp,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeShareExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeApp,
                newState: .willRelease
            ),

            // 2.1.2 Received state `using`
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeShareExtension,
                myState: .unused,
                myAppType: AppGroupTypeApp,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeShareExtension,
                myState: .using,
                myAppType: AppGroupTypeApp,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeShareExtension,
                myState: .requested,
                myAppType: AppGroupTypeApp,
                newState: .willRelease
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeShareExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeApp,
                newState: .willRelease,
                disconnectBy: .app
            ),

            // 2.1.3 Received state `requested`
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeShareExtension,
                myState: .unused,
                myAppType: AppGroupTypeApp,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeShareExtension,
                myState: .using,
                myAppType: AppGroupTypeApp,
                newState: .willRelease,
                disconnectBy: .app
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeShareExtension,
                myState: .requested,
                myAppType: AppGroupTypeApp,
                newState: .willRelease
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeShareExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeApp,
                newState: .willRelease
            ),

            // 2.1.4 Received state `willRelease`
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeShareExtension,
                myState: .unused,
                myAppType: AppGroupTypeApp,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeShareExtension,
                myState: .using,
                myAppType: AppGroupTypeApp,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeShareExtension,
                myState: .requested,
                myAppType: AppGroupTypeApp,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeShareExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeApp,
                newState: .willRelease
            ),

            // 2.2 Tests cases: Sender is Share Extension / Receiver is Notification Extension
            // 2.2.1 Received state `unused`
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeShareExtension,
                myState: .unused,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeShareExtension,
                myState: .using,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeShareExtension,
                myState: .requested,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeShareExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),

            // 2.2.2 Received state `using`
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeShareExtension,
                myState: .unused,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeShareExtension,
                myState: .using,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease,
                disconnectBy: .notificationExtension
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeShareExtension,
                myState: .requested,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeShareExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease,
                disconnectBy: .notificationExtension
            ),

            // 2.2.3 Received state `requested`
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeShareExtension,
                myState: .unused,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeShareExtension,
                myState: .using,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeShareExtension,
                myState: .requested,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeShareExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),

            // 2.2.4 Received state `willRelease`
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeShareExtension,
                myState: .unused,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeShareExtension,
                myState: .using,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeShareExtension,
                myState: .requested,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeShareExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeNotificationExtension,
                newState: .willRelease
            ),

            // 3.1 Tests cases: Sender is Notification Extension / Receiver is App
            // 3.1.1 Received state `unused`
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .unused,
                myAppType: AppGroupTypeApp,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .using,
                myAppType: AppGroupTypeApp,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .requested,
                myAppType: AppGroupTypeApp,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeApp,
                newState: .willRelease
            ),

            // 3.1.2 Received state `using`
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .unused,
                myAppType: AppGroupTypeApp,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .using,
                myAppType: AppGroupTypeApp,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .requested,
                myAppType: AppGroupTypeApp,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeApp,
                newState: .willRelease,
                disconnectBy: .app
            ),

            // 3.1.3 Received state `requested`
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .unused,
                myAppType: AppGroupTypeApp,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .using,
                myAppType: AppGroupTypeApp,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .requested,
                myAppType: AppGroupTypeApp,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeApp,
                newState: .willRelease
            ),

            // 3.1.4 Received state `willRelease`
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .unused,
                myAppType: AppGroupTypeApp,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .using,
                myAppType: AppGroupTypeApp,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .requested,
                myAppType: AppGroupTypeApp,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeApp,
                newState: .willRelease
            ),

            // 3.2 Tests cases: Sender is Notification Extension / Receiver is Share Extension
            // 3.2.1 Received state `unused`
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .unused,
                myAppType: AppGroupTypeShareExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .using,
                myAppType: AppGroupTypeShareExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .requested,
                myAppType: AppGroupTypeShareExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .unused,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeShareExtension,
                newState: .willRelease
            ),

            // 3.2.2 Received state `using`
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .unused,
                myAppType: AppGroupTypeShareExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .using,
                myAppType: AppGroupTypeShareExtension,
                newState: .willRelease,
                disconnectBy: .shareExtension
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .requested,
                myAppType: AppGroupTypeShareExtension,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .using,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeShareExtension,
                newState: .willRelease,
                disconnectBy: .shareExtension
            ),

            // 3.2.3 Received state `requested`
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .unused,
                myAppType: AppGroupTypeShareExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .using,
                myAppType: AppGroupTypeShareExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .requested,
                myAppType: AppGroupTypeShareExtension,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .requested,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeShareExtension,
                newState: .willRelease
            ),

            // 3.2.4 Received state `willRelease`
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .unused,
                myAppType: AppGroupTypeShareExtension,
                newState: .unused
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .using,
                myAppType: AppGroupTypeShareExtension,
                newState: .using
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .requested,
                myAppType: AppGroupTypeShareExtension,
                newState: .requested
            ),
            TestCaseAccessState(
                receivedState: .willRelease,
                fromAppType: AppGroupTypeNotificationExtension,
                myState: .willRelease,
                myAppType: AppGroupTypeShareExtension,
                newState: .willRelease
            ),
        ]
    )
    func testReceivedAccessStates(_ testCase: TestCaseAccessState) throws {
        let serverConnectorMock = ServerConnectorMock()
        let processCoordinator = ProcessCoordinator(
            myAppType: testCase.myAppType,
            state: testCase.myState,
            serverConnector: serverConnectorMock,
            userSettings: UserSettingsMock()
        )

        let result = processCoordinator.testProcess(state: testCase.receivedState, from: testCase.fromAppType)
        #expect(result == testCase.newState, "Test case: \(testCase)")

        if let disconnectBy = testCase.disconnectBy {
            #expect(serverConnectorMock.disconnectCalls.contains(disconnectBy), "Test case: \(testCase)")
        }
        else {
            #expect(serverConnectorMock.disconnectCalls.isEmpty, "Test case: \(testCase)")
        }
    }

    @Test func testAppRequestAccess() async throws {
        let processCoordinator = ProcessCoordinator(
            myAppType: AppGroupTypeApp,
            state: .requested,
            serverConnector: ServerConnectorMock(),
            userSettings: UserSettingsMock()
        )

        let state = await processCoordinator.requestAccess(pollingTimeout: 700)

        #expect(state == .using)

        try #require(ddLoggerMock.exists(message: "[Darwin] No answer to request access"))
    }

    @Test func testIsNotificationExtensionRequestedAppPostRequested() async throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.ipcSecretPrefix = BytesUtility.generateRandomBytes(length: 8)

        let processCoordinator: ProcessCoordinator? = ProcessCoordinator(
            myAppType: AppGroupTypeNotificationExtension,
            state: .requested,
            serverConnector: ServerConnectorMock(),
            userSettings: userSettingsMock
        )

        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(30)) {
            DarwinNotificationCenter.shared.post(.notificationName(
                appType: AppGroupTypeApp,
                secret: userSettingsMock.ipcSecretPrefix!.hexString,
                state: .requested
            ))
        }

        let state = await processCoordinator?.requestAccess(pollingTimeout: 700)

        let stateResult = try #require(state)
        #expect(stateResult == .willRelease)
        try #require(!ddLoggerMock.exists(message: "[Darwin] No answer to inquiry"))
    }

    @Test func testNotificationExtensionRequestedAppPostUsing() async throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.ipcSecretPrefix = BytesUtility.generateRandomBytes(length: 8)

        let processCoordinator = ProcessCoordinator(
            myAppType: AppGroupTypeNotificationExtension,
            state: .requested,
            serverConnector: ServerConnectorMock(),
            userSettings: userSettingsMock
        )

        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(30)) {
            DarwinNotificationCenter.shared.post(.notificationName(
                appType: AppGroupTypeApp,
                secret: userSettingsMock.ipcSecretPrefix!.hexString,
                state: .using
            ))
        }

        let state = await processCoordinator.requestAccess(pollingTimeout: 700)

        #expect(state == .willRelease)
        #expect(!ddLoggerMock.exists(message: "[Darwin] No answer to inquiry"))
    }

    /// As long as the Notification Extension announces `using`, the App must keep
    /// waiting - even across the recursive `requestAccess` calls that `ServerConnector` performs
    /// when it gets a `requested` result.
    @Test func testAppDoesNotGrabResourceWhileNotificationExtensionUsing() async throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.ipcSecretPrefix = BytesUtility.generateRandomBytes(length: 8)

        let processCoordinator = ProcessCoordinator(
            myAppType: AppGroupTypeApp,
            state: .requested,
            serverConnector: ServerConnectorMock(),
            userSettings: userSettingsMock
        )

        // The Notification Extension keeps announcing that it is using the resource for the whole
        // duration of the (recursive) requests below.
        @Sendable func postUsing(remaining: Int) {
            guard remaining > 0 else {
                return
            }
            DarwinNotificationCenter.shared.post(.notificationName(
                appType: AppGroupTypeNotificationExtension,
                secret: userSettingsMock.ipcSecretPrefix!.hexString,
                state: .using
            ))
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(20)) {
                postUsing(remaining: remaining - 1)
            }
        }
        postUsing(remaining: 150)

        // Mirror `ServerConnector`'s behaviour: on `requested` it requests access again.
        var state = await processCoordinator.requestAccess(pollingTimeout: 700)
        #expect(state != .using)

        var iterations = 0
        while state == .requested, iterations < 4 {
            state = await processCoordinator.requestAccess(pollingTimeout: 700)
            #expect(state != .using)
            iterations += 1
        }
    }
}
