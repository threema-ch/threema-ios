//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
@testable import GroupCalls

final class GroupCallActorTests: XCTestCase {
    func testBasicInit() throws {
        let dependencies = MockDependencies().create()
        let gck = Data(repeating: 0x01, count: 32)
        
        let groupCallActor = try! GroupCallActor(
            localIdentity: try! ThreemaID(id: "ECHOECHO"),
            groupModel: GroupCallsThreemaGroupModel(
                creator: try! ThreemaID(id: "ECHOECHO"),
                groupID: Data(),
                groupName: "ECHOECHO",
                members: Set([])
            ),
            sfuBaseURL: "",
            gck: gck,
            dependencies: dependencies
        )
    }
    
    func testBasicStillRunning() async throws {
        let dependencies = MockDependencies().create()

        let groupCallActor = try! GroupCallActor(
            localIdentity: try! ThreemaID(id: "ECHOECHO"),
            groupModel: GroupCallsThreemaGroupModel(
                creator: try! ThreemaID(id: "ECHOECHO"),
                groupID: Data(),
                groupName: "ECHOECHO",
                members: Set([])
            ),
            sfuBaseURL: "",
            gck: Data(repeating: 0x01, count: 32),
            dependencies: dependencies
        )

        let result = try await groupCallActor.stillRunning() == .running

        XCTAssertTrue(result)
    }
    
    func testBasicNotRunningAnymore() async throws {
        let mockHTTPClient = MockHTTPClient(returnCode: 404)

        let dependencies = MockDependencies().with(mockHTTPClient).create()

        let gck = Data(repeating: 0x01, count: 32)

        let groupCallActor = try! GroupCallActor(
            localIdentity: try! ThreemaID(id: "ECHOECHO"),
            groupModel: GroupCallsThreemaGroupModel(
                creator: try! ThreemaID(id: "ECHOECHO"),
                groupID: Data(),
                groupName: "ECHOECHO",
                members: Set([])
            ),
            sfuBaseURL: "",
            gck: gck,
            dependencies: dependencies
        )

        let result = try await groupCallActor.stillRunning() == .running

        XCTAssertFalse(result)
    }
    
    func testTenHoursAgo() async throws {
        let dependencies = MockDependencies().create()

        let gck = Data(repeating: 0x01, count: 32)

        let groupCallActor = try! GroupCallActor(
            localIdentity: try! ThreemaID(id: "ECHOECHO"),
            groupModel: GroupCallsThreemaGroupModel(
                creator: try! ThreemaID(id: "ECHOECHO"),
                groupID: Data(),
                groupName: "ECHOECHO",
                members: Set([])
            ),
            sfuBaseURL: "",
            gck: gck,
            startMessageReceiveDate: Date.distantPast,
            dependencies: dependencies
        )
        
        XCTAssertTrue(groupCallActor.receivedMoreThan10HoursAgo)
    }
}
