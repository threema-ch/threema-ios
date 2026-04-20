import XCTest
@testable import ThreemaFramework

final class QueueTests: XCTestCase {

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
    
    func testRemoveAllWhere() {
        var expectedItems = [Int]()
        var expectedRemovedItems = [Int]()
        
        var queue = Queue<Int>()
        
        for index in 1...10 {
            queue.enqueue(index)
            
            if index % 2 == 0 {
                expectedRemovedItems.append(index)
            }
            else {
                expectedItems.append(index)
            }
        }
        
        XCTAssertEqual(queue.list.count, expectedItems.count + expectedRemovedItems.count)
        
        let actualRemovedItems = queue.removeAll(where: { $0 % 2 == 0 })
        
        XCTAssertEqual(actualRemovedItems, expectedRemovedItems)
        XCTAssertEqual(queue.list, expectedItems)
    }
}
