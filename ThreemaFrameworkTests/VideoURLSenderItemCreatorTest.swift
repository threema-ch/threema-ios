import FileUtility
import XCTest
@testable import ThreemaFramework

final class VideoURLSenderItemCreatorTest: XCTestCase {
    
    private let videoName = "Video-1"
    private var senderItemCreator: VideoURLSenderItemCreator!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        FileUtility.updateSharedInstance(with: FileUtility())
        
        /// Use low-quality helper so all tests use the fastest preset and avoid
        /// calling UserSettings.shared() which is unavailable in the test process.
        let helper = VideoConversionHelper(
            userSettings: UserSettingsMock(videoQuality: "low"),
            outputDirectoryURL: FileManager.default.temporaryDirectory
        )
        senderItemCreator = VideoURLSenderItemCreator(videoConversionHelper: helper)
    }
    
    override func tearDownWithError() throws {
        senderItemCreator = nil
    }
    
    func testVideoConversion() throws {
        let testBundle = Bundle(for: VideoURLSenderItemCreatorTest.self)
        let testVideoURL = testBundle.url(forResource: videoName, withExtension: "mp4")
        let asset = AVURLAsset(url: testVideoURL!)

        let videoURL = senderItemCreator.convertVideo(asset: asset)
        
        let expect = expectation(description: "Video Conversion")
        
        var url: URL?
        
        videoURL.done { vidURL in
            url = vidURL
            expect.fulfill()
        }.catch { _ in
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
        guard let url else {
            return XCTFail("Expected a valid URL")
        }
        let uti = UTIConverter.uti(forFileURL: url) ?? UTType.data.identifier
        guard let mimeType = UTIConverter.mimeType(fromUTI: uti) else {
            return XCTFail("Expected a mimeType not nil")
        }
        XCTAssert(UTIConverter.isRenderingVideoMimeType(mimeType))
    }
    
    func testGetThumbnail() {
        
        let testBundle = Bundle(for: VideoURLSenderItemCreatorTest.self)
        let testVideoURL = testBundle.url(forResource: videoName, withExtension: "mp4")
        let asset = AVURLAsset(url: testVideoURL!)
        
        let expect = expectation(description: "Video Creation")
        
        senderItemCreator.getThumbnail(asset: asset).done { _ in
            expect.fulfill()
        }.catch { _ in
            XCTFail()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
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
            let item = senderItemCreator.senderItem(from: url)
            XCTAssert(item == nil)
        }
    }
}
