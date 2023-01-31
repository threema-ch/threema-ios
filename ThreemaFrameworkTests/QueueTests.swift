//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

class QueueTests: XCTestCase {

    func testEnqueueDequeuePeekList() {
        var expectedItems = [String]()

        var queue = Queue<String>()

        for i in 1...5 {
            expectedItems.append("test \(i)")
            queue.enqueue(expectedItems[i - 1])
        }
        XCTAssertEqual(queue.list.count, 5)

        let peekItem1 = queue.peek()
        XCTAssertEqual(peekItem1, expectedItems[0])

        var list = queue.list
        list.removeAll()
        XCTAssertEqual(list.count, 0)
        XCTAssertEqual(queue.list.count, 5)

        let peekItem2 = queue.peek()
        XCTAssertEqual(peekItem2, expectedItems[0])

        var i = 0
        while let item = queue.dequeue() {
            XCTAssertEqual(item, expectedItems[i])
            i += 1
        }

        XCTAssertEqual(queue.list.count, 0)
    }
}
