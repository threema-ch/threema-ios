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

import CocoaLumberjackSwift
import Testing
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
                newState: .using
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
                newState: .willRelease
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
                newState: .willRelease
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
                newState: .willRelease
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
                newState: .willRelease
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
                newState: .willRelease
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
                newState: .willRelease
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
                newState: .willRelease
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
                newState: .willRelease
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
                newState: .willRelease
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
                newState: .using
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
                newState: .willRelease
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
        let processCoordinator = ProcessCoordinator(
            myAppType: testCase.myAppType,
            state: testCase.myState,
            serverConnector: ServerConnectorMock(),
            userSettings: UserSettingsMock()
        )

        let result = processCoordinator.testProcess(state: testCase.receivedState, from: testCase.fromAppType)
        #expect(result == testCase.newState)
    }

    @Test func testAppRequestAccess() async throws {
        let processCoordinator = ProcessCoordinator(
            myAppType: AppGroupTypeApp,
            state: .requested,
            serverConnector: ServerConnectorMock(),
            userSettings: UserSettingsMock()
        )

        let state = await processCoordinator.requestAccess()

        #expect(state == .using)

        try #require(ddLoggerMock.exists(message: "[Darwin] No answer to request access"))
    }

    @Test func testIsNotificationExtensionRequestedAppPostRequested() async throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.ipcSecretPrefix = BytesUtility.generateRandomBytes(length: 8)

        var processCoordinator: ProcessCoordinator? = ProcessCoordinator(
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

        let state = await processCoordinator?.requestAccess()

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

        let state = await processCoordinator.requestAccess()

        let stateResult = try #require(state)
        #expect(stateResult == .willRelease)
        #expect(!ddLoggerMock.exists(message: "[Darwin] No answer to inquiry"))
    }
}
