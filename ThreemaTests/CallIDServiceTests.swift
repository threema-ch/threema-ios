//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2026-2025 Threema GmbH
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

import Testing
@testable import Threema

struct CallIDServiceTests {

    @Test func testUUIDForCallID() async throws {
        let expectedCallIDOne = VoIPCallID.generate()
        let expectedCallIDTwo = VoIPCallID.generate()

        let callIDService = CallIDService()

        let (uuidOne, isNewOne) = callIDService.uuid(for: expectedCallIDOne)
        let (uuidTwo, isNewTwo) = callIDService.uuid(for: expectedCallIDTwo)

        let (uuidOneSecond, isNewOneSecond) = callIDService.uuid(for: expectedCallIDOne)
        let (uuidTwoSecond, isNewTwoSecond) = callIDService.uuid(for: expectedCallIDTwo)

        #expect(isNewOne)
        #expect(!isNewOneSecond)
        #expect(uuidOne == uuidOneSecond)

        #expect(isNewTwo)
        #expect(!isNewTwoSecond)
        #expect(uuidTwo == uuidTwoSecond)

        #expect(uuidOne != uuidTwo)
        #expect(uuidOneSecond != uuidTwoSecond)
    }

    @Test func testCallIDIsNilForUnknownUUID() async throws {
        let callIDService = CallIDService()

        let callID = callIDService.callID(for: UUID())

        #expect(callID == nil)
    }

    @Test func testCallIDForUUID() async throws {
        let expectedCallIDOne = VoIPCallID.generate()
        let expectedCallIDTwo = VoIPCallID.generate()

        let callIDService = CallIDService()

        let (uuidOne, isNewOne) = callIDService.uuid(for: expectedCallIDOne)
        let (uuidTwo, isNewTwo) = callIDService.uuid(for: expectedCallIDTwo)

        #expect(isNewOne)
        #expect(isNewTwo)
        #expect(uuidOne != uuidTwo)

        let callIDOne = callIDService.callID(for: uuidOne)
        let callIDTwo = callIDService.callID(for: uuidTwo)

        #expect(callIDOne?.callID == expectedCallIDOne.callID)
        #expect(callIDTwo?.callID == expectedCallIDTwo.callID)
    }
}
