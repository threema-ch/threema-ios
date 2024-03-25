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

import XCTest
@testable import Threema

final class VoIPCallServiceTests: XCTestCase {

    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
    }

    func testPeerConnectionClientDidChangeConnectionState() throws {
        let voIPCallPeerConnectionClientMock = VoIPCallPeerConnectionClientMock()

        let voIPCallService = VoIPCallService(
            businessInjector: BusinessInjectorMock(
                entityManager: EntityManager(databaseContext: dbMainCnx)
            ),
            peerConnectionClient: voIPCallPeerConnectionClientMock
        )
        voIPCallPeerConnectionClientMock.delegate = voIPCallService

        XCTAssertEqual(voIPCallService.currentState(), .idle)

        voIPCallPeerConnectionClientMock.delegate?.peerConnectionClient(
            voIPCallPeerConnectionClientMock,
            didChangeConnectionState: .connecting
        )

        XCTAssertEqual(voIPCallService.currentState(), .initializing)
    }
}
