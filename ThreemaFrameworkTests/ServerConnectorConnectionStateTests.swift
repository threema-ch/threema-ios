import Foundation

import XCTest
@testable import ThreemaFramework

final class ServerConnectorConnectionStateTests: XCTestCase {
    var changedCalls: [ConnectionState]!

    override func setUpWithError() throws {
        changedCalls = [ConnectionState]()
    }

    func testConnected() {
        for isMultiDeviceEnabled in [true, false] {
            changedCalls.removeAll()

            let userSettingsMock = UserSettingsMock()
            userSettingsMock.enableMultiDevice = isMultiDeviceEnabled

            let serverConnectionState = ServerConnectorConnectionState(
                userSettings: userSettingsMock,
                connectionStateDelegate: self
            )
            serverConnectionState.connected()

            XCTAssertEqual(serverConnectionState.connectionState, .connected)
            XCTAssertEqual(changedCalls.count, 1)
            XCTAssertEqual(changedCalls.first, .connected)
        }
    }

    func testConnecting() {
        for isMultiDeviceEnabled in [true, false] {
            changedCalls.removeAll()

            let userSettingsMock = UserSettingsMock()
            userSettingsMock.enableMultiDevice = isMultiDeviceEnabled

            let serverConnectionState = ServerConnectorConnectionState(
                userSettings: userSettingsMock,
                connectionStateDelegate: self
            )
            serverConnectionState.connecting()

            XCTAssertEqual(serverConnectionState.connectionState, .connecting)
            XCTAssertEqual(changedCalls.count, 1)
            XCTAssertEqual(changedCalls.first, .connecting)
        }
    }

    func testDisconnected() {
        for isMultiDeviceEnabled in [true, false] {
            let userSettingsMock = UserSettingsMock()
            userSettingsMock.enableMultiDevice = isMultiDeviceEnabled

            let serverConnectionState = ServerConnectorConnectionState(
                userSettings: userSettingsMock,
                connectionStateDelegate: self
            )
            serverConnectionState.connected() // Set to connected first
            changedCalls.removeAll()

            serverConnectionState.disconnected()

            XCTAssertEqual(serverConnectionState.connectionState, .disconnected)
            XCTAssertEqual(changedCalls.count, 1)
            XCTAssertEqual(changedCalls.first, .disconnected)
        }
    }

    func testDisconnecting() {
        for isMultiDeviceEnabled in [true, false] {
            changedCalls.removeAll()

            let userSettingsMock = UserSettingsMock()
            userSettingsMock.enableMultiDevice = isMultiDeviceEnabled

            let serverConnectionState = ServerConnectorConnectionState(
                userSettings: userSettingsMock,
                connectionStateDelegate: self
            )
            serverConnectionState.disconnecting()

            XCTAssertEqual(serverConnectionState.connectionState, .disconnecting)
            XCTAssertEqual(changedCalls.count, 1)
            XCTAssertEqual(changedCalls.first, .disconnecting)
        }
    }

    func testWaitForStateDisconnected() {
        for isMultiDeviceEnabled in [true, false] {
            let userSettingsMock = UserSettingsMock()
            userSettingsMock.enableMultiDevice = isMultiDeviceEnabled

            let serverConnectionState = ServerConnectorConnectionState(
                userSettings: userSettingsMock,
                connectionStateDelegate: self
            )
            serverConnectionState.loggedInChatServer()
            serverConnectionState.loggedInMediatorServer()
            changedCalls.removeAll()

            DispatchQueue.global().async {
                serverConnectionState.disconnecting()
                serverConnectionState.disconnected()
            }

            serverConnectionState.waitForStateDisconnected()

            XCTAssertEqual(serverConnectionState.connectionState, .disconnected)
            XCTAssertEqual(changedCalls.count, 2)
            XCTAssertEqual(changedCalls.first, .disconnecting)
            XCTAssertEqual(changedCalls.last, .disconnected)
        }
    }

    func testLoggedInChatServer() {
        for isMultiDeviceEnabled in [true, false] {
            changedCalls.removeAll()

            let userSettingsMock = UserSettingsMock()
            userSettingsMock.enableMultiDevice = isMultiDeviceEnabled

            let serverConnectionState = ServerConnectorConnectionState(
                userSettings: userSettingsMock,
                connectionStateDelegate: self
            )
            serverConnectionState.loggedInChatServer()

            if isMultiDeviceEnabled {
                XCTAssertEqual(serverConnectionState.connectionState, .disconnected)
                XCTAssertEqual(changedCalls.count, 1)
            }
            else {
                XCTAssertEqual(serverConnectionState.connectionState, .loggedIn)
                XCTAssertEqual(changedCalls.count, 1)
                XCTAssertEqual(changedCalls.first, .loggedIn)
            }
        }
    }

    func testLoggedInMediatorServer() {
        for isMultiDeviceEnabled in [true, false] {
            changedCalls.removeAll()

            let userSettingsMock = UserSettingsMock()
            userSettingsMock.enableMultiDevice = isMultiDeviceEnabled

            let serverConnectionState = ServerConnectorConnectionState(
                userSettings: userSettingsMock,
                connectionStateDelegate: self
            )
            serverConnectionState.loggedInMediatorServer()

            XCTAssertEqual(serverConnectionState.connectionState, .disconnected)
            XCTAssertEqual(changedCalls.count, 1)
        }
    }

    func testLoggedIn() {
        for isMultiDeviceEnabled in [true, false] {
            changedCalls.removeAll()

            let userSettingsMock = UserSettingsMock()
            userSettingsMock.enableMultiDevice = isMultiDeviceEnabled

            let serverConnectionState = ServerConnectorConnectionState(
                userSettings: userSettingsMock,
                connectionStateDelegate: self
            )
            serverConnectionState.loggedInChatServer()
            serverConnectionState.loggedInMediatorServer()

            XCTAssertEqual(serverConnectionState.connectionState, .loggedIn)
            XCTAssertEqual(changedCalls.count, 2)
            XCTAssertEqual(changedCalls.last, .loggedIn)
        }
    }
}

// MARK: - ConnectionStateDelegate

extension ServerConnectorConnectionStateTests: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        changedCalls.append(state)
    }
}
