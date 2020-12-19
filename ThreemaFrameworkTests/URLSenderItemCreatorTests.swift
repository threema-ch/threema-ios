//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020 Threema GmbH
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

class URLSenderItemCreatorTests: XCTestCase {

    let testBundle: Bundle = Bundle(for: ImageURLSenderItemCreatorTest.self)
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // necessary for ValidationLogger
        AppGroup.setGroupId("group.ch.threema") //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCreateSenderFromURL() {
        let imageURLSenderItemCreatorTest = ImageURLSenderItemCreatorTest()
        for item in imageURLSenderItemCreatorTest.testMatrix {
            guard let testImageUrl = imageURLSenderItemCreatorTest.testBundle.url(forResource: item.0, withExtension: item.1) else {
                XCTFail("Could not create testImageURL")
                return
            }
            guard let senderItem = URLSenderItemCreator.getSenderItem(for: testImageUrl, maxSize: item.2) else {
                XCTFail("Could not create senderItem from valid testdata")
                return
            }
            imageURLSenderItemCreatorTest.checkSenderItem(senderItem: senderItem, item: item)
        }
    }
    
    func testGarbageURL() {
        let urlMatrix : [String] = [
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
