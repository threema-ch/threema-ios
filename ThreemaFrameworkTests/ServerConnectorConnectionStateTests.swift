//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

import Foundation

import XCTest
@testable import ThreemaFramework

class ServerConnectorConnectionStateTests: XCTestCase {
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

            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
                serverConnectionState.disconnecting()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2)) {
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
                XCTAssertEqual(changedCalls.count, 0)
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
            XCTAssertEqual(changedCalls.count, 0)
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
            XCTAssertEqual(changedCalls.count, 1)
            XCTAssertEqual(changedCalls.first, .loggedIn)
        }
    }
}

// MARK: - ConnectionStateDelegate

extension ServerConnectorConnectionStateTests: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        changedCalls.append(state)
    }
}
