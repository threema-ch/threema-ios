import FileUtility
import XCTest
@testable import ThreemaFramework

final class URLSenderItemCreatorTests: XCTestCase {

    let testBundle = Bundle(for: ImageURLSenderItemCreatorTest.self)
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        FileUtility.updateSharedInstance(with: FileUtility())
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCreateSenderFromURL() {
        let imageURLSenderItemCreatorTest = ImageURLSenderItemCreatorTest()
        for item in imageURLSenderItemCreatorTest.testMatrix {
            guard let testImageURL = imageURLSenderItemCreatorTest.testBundle.url(
                forResource: item.0,
                withExtension: item.1
            ) else {
                XCTFail("Could not create testImageURL for \(item.0).\(item.1)")
                return
            }
            guard let senderItem = URLSenderItemCreator.getSenderItem(for: testImageURL, maxSize: item.2) else {
                XCTFail("Could not create senderItem from valid testdata \(item.0).\(item.1)")
                return
            }
            imageURLSenderItemCreatorTest.checkSenderItem(senderItem: senderItem, item: item)
        }
    }
    
    func testGarbageURL() {
        let urlMatrix: [String] = [
            "https://threema.ch/en",
            "file://threema.ch/en",
        ]
        
        for urlString in urlMatrix {
            guard let url = URL(string: urlString) else {
                XCTFail("Invalid test parameter \(urlString)")
                return
            }
            let item = URLSenderItemCreator.getSenderItem(for: url)
            XCTAssert(item == nil, "\(url)")
        }
    }
}
