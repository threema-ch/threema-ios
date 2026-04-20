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
