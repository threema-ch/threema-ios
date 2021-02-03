//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

class ImageURLSenderItemCreatorTest: XCTestCase {
    
    let testBundle: Bundle = Bundle(for: ImageURLSenderItemCreatorTest.self)
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // necessary for ValidationLogger
        AppGroup.setGroupId("group.ch.threema") //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    
    static private let jpg1 = "Bild-1-0"
    static private let heic1 = "Bild-2"
    static private let heic2 = "Bild-3"
    static private let pngRegular = "Bild-4"
    static private let pngSticker = "Bild-5-0"
    static private let pngAlpha = "Bild-5-1"
    static private let gifStatic = "Bild-6"
    static private let rawFilename = "Bild-7"
    static private let pngScreenshot = "Bild-8"
    
    let testMatrix : [(String, String, String, CGFloat, CFString, NSNumber)] = [
        (heic1, "heic", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (heic1, "heic", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (heic1, "heic", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (heic1, "heic", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (heic1, "heic", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (jpg1, "jpg", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (jpg1, "jpg", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (jpg1, "jpg", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (jpg1, "jpg", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (jpg1, "jpg", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (gifStatic, "gif", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeGIF, 2),
        (gifStatic, "gif", "xLarge", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeGIF, 2),
        (gifStatic, "gif", "large", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeGIF, 2),
        (gifStatic, "gif", "medium", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeGIF, 2),
        (gifStatic, "gif", "small", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeGIF, 2),
        (pngRegular, "png", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (pngRegular, "png", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (pngRegular, "png", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (pngRegular, "png", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (pngRegular, "png", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (pngSticker, "png", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypePNG, 2),
        (pngSticker, "png", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypePNG, 2),
        (pngSticker, "png", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypePNG, 2),
        (pngSticker, "png", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypePNG, 2),
        (pngSticker, "png", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypePNG, 2),
        (pngScreenshot, "png", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (pngScreenshot, "png", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (pngScreenshot, "png", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (pngScreenshot, "png", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (pngScreenshot, "png", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (pngRegular, "png", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (pngRegular, "png", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (pngRegular, "png", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (pngRegular, "png", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (pngRegular, "png", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (pngRegular, "png", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (pngRegular, "png", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (pngRegular, "png", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (pngRegular, "png", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (pngRegular, "png", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "srf", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "srf", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "srf", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "srf", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "srf", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "sr2", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "sr2", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "sr2", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "sr2", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "sr2", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "raf", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "raf", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "raf", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "raf", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "raf", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "pef", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "pef", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "pef", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "pef", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "pef", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "orf", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "orf", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "orf", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "orf", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "orf", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "nef", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "nef", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "nef", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "nef", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "nef", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "mrw", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "mrw", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "mrw", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "mrw", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "mrw", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "erf", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "erf", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "erf", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "erf", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "erf", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "dng", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "dng", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "dng", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "dng", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "dng", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "dcr", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "dcr", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "dcr", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "dcr", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "dcr", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "crw", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "crw", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "crw", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "crw", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "crw", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "cr2", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "cr2", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "cr2", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "cr2", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "cr2", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "arw", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "arw", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "arw", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "arw", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "arw", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
        (rawFilename, "raw", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
        (rawFilename, "raw", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
        (rawFilename, "raw", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
        (rawFilename, "raw", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
        (rawFilename, "raw", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
    ]
    
    func testImageSize() throws {
        let matrix : [(String, String, String, CGFloat)] = [
            ("Bild-1-1", "jpg", "original", 4592),
            (ImageURLSenderItemCreatorTest.jpg1, "jpg", "original", 1837),
            (ImageURLSenderItemCreatorTest.jpg1, "jpg", "small", ImageURLSenderItemCreator.kImageSizeSmall),
            (ImageURLSenderItemCreatorTest.jpg1, "jpg", "medium", ImageURLSenderItemCreator.kImageSizeMedium),
            (ImageURLSenderItemCreatorTest.jpg1, "jpg", "large", ImageURLSenderItemCreator.kImageSizeLarge),
            (ImageURLSenderItemCreatorTest.jpg1, "jpg", "xlarge", ImageURLSenderItemCreator.kImageSizeXLarge),
            (ImageURLSenderItemCreatorTest.heic1, "heic", "small", ImageURLSenderItemCreator.kImageSizeSmall),
            (ImageURLSenderItemCreatorTest.heic1, "heic", "medium", ImageURLSenderItemCreator.kImageSizeMedium),
            (ImageURLSenderItemCreatorTest.heic1, "heic", "large", ImageURLSenderItemCreator.kImageSizeLarge),
            (ImageURLSenderItemCreatorTest.heic1, "heic", "xlarge", ImageURLSenderItemCreator.kImageSizeXLarge)]
        
        for item in matrix {
            let testImageUrl = testBundle.url(forResource: item.0, withExtension: item.1)
            let testImageData = (try? Data(contentsOf: testImageUrl!))!
            let image = UIImage(data: testImageData)!
            
            let itemCreator = ImageURLSenderItemCreator(with: item.2, forceSize: true)
            
            let resolution = itemCreator.imageMaxSize(image)
            XCTAssert(resolution == item.3, "Expected \(item.3) but received \(resolution)")
        }
        
    }
    
    func testNumberOfImageSizes() {
        let noSizes = 5
        XCTAssert(ImageURLSenderItemCreator.getImageSizeNo() == noSizes, "Number of sizes should be \(noSizes). Check if settings still work.")
    }
    
    func testPixelSizes() {
        let sizes = ImageURLSenderItemCreator.imagePixelSizes()!
        XCTAssert(sizes[0] as! CGFloat == ImageURLSenderItemCreator.kImageSizeSmall)
        XCTAssert(sizes[1] as! CGFloat == ImageURLSenderItemCreator.kImageSizeMedium)
        XCTAssert(sizes[2] as! CGFloat == ImageURLSenderItemCreator.kImageSizeLarge)
        XCTAssert(sizes[3] as! CGFloat == ImageURLSenderItemCreator.kImageSizeXLarge)
        XCTAssert(sizes[4] as! CGFloat == ImageURLSenderItemCreator.kImageSizeOriginal)
    }
    
    func testCreateSenderFromUIImage() {
        let matrix : [(filename : String, String, String, CGFloat, expectedMimeType : CFString, NSNumber)] = [
            (ImageURLSenderItemCreatorTest.pngRegular, "png", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 1),
            (ImageURLSenderItemCreatorTest.pngRegular, "png", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 1),
            (ImageURLSenderItemCreatorTest.pngRegular, "png", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 1),
            (ImageURLSenderItemCreatorTest.pngRegular, "png", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 1),
            (ImageURLSenderItemCreatorTest.pngRegular, "png", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 1),
            (ImageURLSenderItemCreatorTest.pngSticker, "png", "original", ImageURLSenderItemCreator.kImageSizeOriginal, kUTTypeJPEG, 2),
            (ImageURLSenderItemCreatorTest.pngSticker, "png", "xLarge", ImageURLSenderItemCreator.kImageSizeXLarge, kUTTypeJPEG, 2),
            (ImageURLSenderItemCreatorTest.pngSticker, "png", "large", ImageURLSenderItemCreator.kImageSizeLarge, kUTTypeJPEG, 2),
            (ImageURLSenderItemCreatorTest.pngSticker, "png", "medium", ImageURLSenderItemCreator.kImageSizeMedium, kUTTypeJPEG, 2),
            (ImageURLSenderItemCreatorTest.pngSticker, "png", "small", ImageURLSenderItemCreator.kImageSizeSmall, kUTTypeJPEG, 2)
        ]
        
        let specialTestMatrix = testMatrix[0..<10] + matrix
        
        for item in specialTestMatrix {
            let testImageUrl = testBundle.url(forResource: item.0, withExtension: item.1)
            let testImageData = (try? Data(contentsOf: testImageUrl!))!
            let image = UIImage(data: testImageData)!
            
            let itemCreator = ImageURLSenderItemCreator(with: item.2, forceSize: true)
            
            let senderItem = itemCreator.senderItem(fromImage: image)
            XCTAssert(senderItem!.caption == nil)
            XCTAssert(senderItem!.getMimeType() == UTIConverter.mimeType(fromUTI: item.4 as String), "\(item.0) had mime type \(senderItem!.getMimeType()) but expected \(item.4)")
            XCTAssertNotNil(senderItem!.getThumbnail())
        }
    }
    
    func testCreateSenderFromData() {
        for item in testMatrix {
            let testImageUrl = testBundle.url(forResource: item.0, withExtension: item.1)
            let testImageData = (try? Data(contentsOf: testImageUrl!))!
            let itemCreator = ImageURLSenderItemCreator(with: item.2, forceSize: true)
            guard let senderItem = itemCreator.senderItem(from: testImageData, uti: item.4 as String) else {
                XCTFail("Could not create senderItem from valid testdata \(testImageUrl)")
                return
            }
            checkSenderItem(senderItem: senderItem, item: item)
        }
    }
    
    func testCreateSenderFromURL() {
        for item in testMatrix {
            let testImageUrl = testBundle.url(forResource: item.0, withExtension: item.1)
            let itemCreator = ImageURLSenderItemCreator(with: item.2, forceSize: true)
            guard let senderItem = itemCreator.senderItem(from: testImageUrl!) else {
                XCTFail("Could not create senderItem from valid testdata \(String(describing: testImageUrl))")
                return
            }
            checkSenderItem(senderItem: senderItem, item: item)
        }
    }
    
    func checkSenderItem(senderItem : URLSenderItem, item : (String, String, String, CGFloat, CFString, NSNumber)) {
        let testImageUrl = testBundle.url(forResource: item.0, withExtension: item.1)
        let testImageData = (try? Data(contentsOf: testImageUrl!))!
        let image = UIImage(data: testImageData)!
        
        var height = item.3
        if height == 0.0 {
            height = image.size.height
        }
        var width = item.3
        if width == 0.0 {
            width = image.size.width
        }
        
        XCTAssert(senderItem.caption == nil)
        
        let goldUTI = UTIConverter.mimeType(fromUTI: item.4 as String)
        let actualUTI = senderItem.getMimeType()
        XCTAssert(actualUTI == goldUTI, "UTI must be \(String(describing: goldUTI)) but is \(String(describing: actualUTI))")
        XCTAssert(senderItem.getHeight() <= height, "\(item.0): \(senderItem.getHeight()) should be less than or equal to \(height)")
        XCTAssert(senderItem.getWidth() <= width, "\(item.0): \(senderItem.getWidth()) should be less than or equal to \(width)")
        XCTAssertNotNil(senderItem.getThumbnail(), "Thumbnail must not be nil")
        XCTAssert(senderItem.renderType! == item.5)
    }
    
    
    func testAllowedUTITypes() {
        let matrix : [(CFString, Bool)] = [(kUTTypePNG, true),
                                           (kUTTypeGIF, true),
                                           (kUTTypeJPEG, true),
                                           (kUTTypeData, false),
                                           (kUTTypeBMP, false),
                                           (kUTTypeMP3, false)]
        
        for item in matrix {
            XCTAssert(ImageURLSenderItemCreator.isAllowedUTI(uti: item.0 as String) == item.1)
        }
    }
    
    func testHasAlpha() {
        let testHasAlphaMatrix : [(String, String, String, Bool, Bool)] = [
            (ImageURLSenderItemCreatorTest.pngRegular, "png", "original", false, false),
            (ImageURLSenderItemCreatorTest.pngSticker, "png", "original", true, true),
            (ImageURLSenderItemCreatorTest.pngScreenshot, "png", "original", false, false),
            (ImageURLSenderItemCreatorTest.pngAlpha, "png", "original", true, false),
        ]
        
        for item in testHasAlphaMatrix {
            let testImageUrl = testBundle.url(forResource: item.0, withExtension: item.1)
            let testImageData = (try? Data(contentsOf: testImageUrl!))!
            let image = UIImage(data: testImageData)!
            let hasAlpha = ImageURLSenderItemCreator.hasAlpha(image: image.cgImage!)
            let hasTransparentPixel = ImageURLSenderItemCreator.hasTransparentPixel(cgImage: image.cgImage!)
            XCTAssert(hasAlpha == item.3, "\(item.0) should be \(item.3) but is \(hasAlpha)")
            XCTAssert(hasTransparentPixel == item.4, "\(item.0) Should be \(item.4) but is \(hasTransparentPixel)")
        }
    }
    
    func testGarbageData() {
        let data = Data(count: 128)
        let creator = ImageURLSenderItemCreator()
        let item = creator.senderItem(from: data, uti: kUTTypeGIF as String)
        XCTAssert(item == nil)
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
            let creator = ImageURLSenderItemCreator()
            let item = creator.senderItem(from: url)
            XCTAssert(item == nil)
        }
    }
}
