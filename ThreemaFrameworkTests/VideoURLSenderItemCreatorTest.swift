//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

class VideoURLSenderItemCreatorTest: XCTestCase {
    
    private let videoName = "Video-1"
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testVideoConversion() throws {
        let testBundle = Bundle(for: VideoURLSenderItemCreatorTest.self)
        let testVideoURL = testBundle.url(forResource: videoName, withExtension: "mp4")
        let asset = AVURLAsset(url: testVideoURL!)
        
        let senderItemCreator = VideoURLSenderItemCreator()
        let videoURL = senderItemCreator.convertVideo(asset: asset)
        
        let expect = expectation(description: "Video Conversion")
        
        var url: URL?
        
        videoURL.done { vidURL in
            url = vidURL
            expect.fulfill()
        }.catch { _ in
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        let mimeType = UTIConverter.mimeType(fromUTI: UTIConverter.uti(forFileURL: url))
        XCTAssert(UTIConverter.isRenderingVideoMimeType(mimeType))
    }
    
    func testGetThumbnail() {
        
        let testBundle = Bundle(for: VideoURLSenderItemCreatorTest.self)
        let testVideoURL = testBundle.url(forResource: videoName, withExtension: "mp4")
        let asset = AVURLAsset(url: testVideoURL!)
        
        let senderItemCreator = VideoURLSenderItemCreator()
        
        let expect = expectation(description: "Video Creation")
        
        senderItemCreator.getThumbnail(asset: asset).done { _ in
            expect.fulfill()
        }.catch { _ in
            XCTFail()
        }
        
        waitForExpectations(timeout: 60, handler: nil)
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
            let creator = VideoURLSenderItemCreator()
            let item = creator.senderItem(from: url)
            XCTAssert(item == nil)
        }
    }
}
