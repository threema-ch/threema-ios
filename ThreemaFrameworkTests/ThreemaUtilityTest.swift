//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
@testable import ThreemaFramework

final class ThreemaUtilityTest: XCTestCase {
    
    let testMatrix: [(input: String, length: Int, numOfMessages: Int)] = [
        ("test", 4, 1),
        ("test Test", 4, 2),
        ("test looong message hype", 4, 6),
        ("test 🥳", 4, 2),
        ("testlooongmessagehype", 4, 6),
        ("te st loo ong m ess age hype", 4, 8),
        ("", 4, 0),
        (" ", 4, 0),
        ("   ", 4, 0),
        ("🧑‍🧑‍🧒‍🧒🧑‍🧑‍🧒‍🧒 🧑‍🧑‍🧒‍🧒 🧑‍🧑‍🧒‍🧒🧑‍🧑‍🧒‍🧒 🧑‍🧑‍🧒‍🧒🧑‍🧑‍🧒‍🧒🧑‍🧑‍🧒‍🧒", 25, 8),
    ]
    
    func testTrimMessageTexts() throws {
        for test in testMatrix {
            let messages = ThreemaUtility.trimMessageText(text: test.input, length: test.length)
            XCTAssertEqual(test.numOfMessages, messages.count)
            for message in messages {
                XCTAssert(Data(message.utf8).count <= test.length)
            }
        }
    }
}
