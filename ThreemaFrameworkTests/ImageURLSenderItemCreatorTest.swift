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

class ImageURLSenderItemCreatorTest: XCTestCase {
    
    let testBundle = Bundle(for: ImageURLSenderItemCreatorTest.self)
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    private static let jpg1 = "Bild-1-0"
    private static let heic1 = "Bild-2"
    private static let heic2 = "Bild-3"
    private static let pngRegular = "Bild-4"
    private static let pngSticker = "Bild-5-0"
    private static let pngAlpha = "Bild-5-1"
    private static let gifStatic = "Bild-6"
    private static let rawFilename = "Bild-7"
    private static let pngScreenshot = "Bild-8"
    
    let testMatrix: [(String, String, ImageSenderItemSize, CGFloat, CFString, NSNumber)] = [
        (heic1, "heic", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (heic1, "heic", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (heic1, "heic", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (heic1, "heic", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (heic1, "heic", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (jpg1, "jpg", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (jpg1, "jpg", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (jpg1, "jpg", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (jpg1, "jpg", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (jpg1, "jpg", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (gifStatic, "gif", .original, ImageSenderItemSize.original.resolution, kUTTypeGIF, 1),
        (gifStatic, "gif", .extraLarge, ImageSenderItemSize.original.resolution, kUTTypeGIF, 1),
        (gifStatic, "gif", .large, ImageSenderItemSize.original.resolution, kUTTypeGIF, 1),
        (gifStatic, "gif", .medium, ImageSenderItemSize.original.resolution, kUTTypeGIF, 1),
        (gifStatic, "gif", .small, ImageSenderItemSize.original.resolution, kUTTypeGIF, 1),
        (pngRegular, "png", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (pngSticker, "png", .original, ImageSenderItemSize.original.resolution, kUTTypePNG, 2),
        (pngSticker, "png", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypePNG, 2),
        (pngSticker, "png", .large, ImageSenderItemSize.large.resolution, kUTTypePNG, 2),
        (pngSticker, "png", .medium, ImageSenderItemSize.medium.resolution, kUTTypePNG, 2),
        (pngSticker, "png", .small, ImageSenderItemSize.small.resolution, kUTTypePNG, 2),
        (pngScreenshot, "png", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (pngScreenshot, "png", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (pngScreenshot, "png", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (pngScreenshot, "png", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (pngScreenshot, "png", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (pngRegular, "png", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "srf", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "srf", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "srf", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "srf", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "srf", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "sr2", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "sr2", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "sr2", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "sr2", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "sr2", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "raf", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "raf", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "raf", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "raf", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "raf", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "pef", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "pef", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "pef", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "pef", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "pef", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "orf", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "orf", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "orf", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "orf", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "orf", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "nef", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "nef", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "nef", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "nef", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "nef", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "mrw", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "mrw", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "mrw", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "mrw", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "mrw", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "erf", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "erf", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "erf", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "erf", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "erf", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "dng", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "dng", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "dng", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "dng", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "dng", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "dcr", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "dcr", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "dcr", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "dcr", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "dcr", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "crw", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "crw", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "crw", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "crw", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "crw", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "cr2", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "cr2", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "cr2", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "cr2", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "cr2", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "arw", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "arw", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "arw", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "arw", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "arw", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
        (rawFilename, "raw", .original, ImageSenderItemSize.original.resolution, kUTTypeJPEG, 1),
        (rawFilename, "raw", .extraLarge, ImageSenderItemSize.extraLarge.resolution, kUTTypeJPEG, 1),
        (rawFilename, "raw", .large, ImageSenderItemSize.large.resolution, kUTTypeJPEG, 1),
        (rawFilename, "raw", .medium, ImageSenderItemSize.medium.resolution, kUTTypeJPEG, 1),
        (rawFilename, "raw", .small, ImageSenderItemSize.small.resolution, kUTTypeJPEG, 1),
    ]
    
    func testImageSize() throws {
        let matrix: [(String, String, ImageSenderItemSize, CGFloat)] = [
            ("Bild-1-1", "jpg", .original, 4592),
            (ImageURLSenderItemCreatorTest.jpg1, "jpg", .original, 1837),
            (ImageURLSenderItemCreatorTest.jpg1, "jpg", .small, ImageSenderItemSize.small.resolution),
            (ImageURLSenderItemCreatorTest.jpg1, "jpg", .medium, ImageSenderItemSize.medium.resolution),
            (ImageURLSenderItemCreatorTest.jpg1, "jpg", .large, ImageSenderItemSize.large.resolution),
            (ImageURLSenderItemCreatorTest.jpg1, "jpg", .extraLarge, ImageSenderItemSize.extraLarge.resolution),
            (ImageURLSenderItemCreatorTest.heic1, "heic", .small, ImageSenderItemSize.small.resolution),
            (ImageURLSenderItemCreatorTest.heic1, "heic", .medium, ImageSenderItemSize.medium.resolution),
            (ImageURLSenderItemCreatorTest.heic1, "heic", .large, ImageSenderItemSize.large.resolution),
            (ImageURLSenderItemCreatorTest.heic1, "heic", .extraLarge, ImageSenderItemSize.extraLarge.resolution),
        ]
        
        for item in matrix {
            let testImageURL = testBundle.url(forResource: item.0, withExtension: item.1)
            let testImageData = (try? Data(contentsOf: testImageURL!))!
            guard let image = UIImage(data: testImageData) else {
                XCTFail("Could not load image")
                return
            }
            
            let itemCreator = ImageURLSenderItemCreator(with: item.2, forceSize: true)
            
            let resolution = itemCreator.imageMaxSize(image)
            XCTAssert(resolution == item.3, "Expected \(item.3) but received \(resolution)")
        }
    }
    
    func testNumberOfImageSizes() {
        let noSizes = 5
        XCTAssert(
            ImageURLSenderItemCreator.imageSizes.count == noSizes,
            "Number of sizes should be \(noSizes). Check if settings still work."
        )
    }
    
    func testCreateSenderFromUIImage() {
        let matrix: [(filename: String, String, ImageSenderItemSize, CGFloat, expectedMimeType: CFString, NSNumber)] = [
            (
                ImageURLSenderItemCreatorTest.pngRegular,
                "png",
                .original,
                ImageSenderItemSize.original.resolution,
                kUTTypeJPEG,
                1
            ),
            (
                ImageURLSenderItemCreatorTest.pngRegular,
                "png",
                .extraLarge,
                ImageSenderItemSize.extraLarge.resolution,
                kUTTypeJPEG,
                1
            ),
            (
                ImageURLSenderItemCreatorTest.pngRegular,
                "png",
                .large,
                ImageSenderItemSize.large.resolution,
                kUTTypeJPEG,
                1
            ),
            (
                ImageURLSenderItemCreatorTest.pngRegular,
                "png",
                .medium,
                ImageSenderItemSize.medium.resolution,
                kUTTypeJPEG,
                1
            ),
            (
                ImageURLSenderItemCreatorTest.pngRegular,
                "png",
                .small,
                ImageSenderItemSize.small.resolution,
                kUTTypeJPEG,
                1
            ),
            (
                ImageURLSenderItemCreatorTest.pngSticker,
                "png",
                .original,
                ImageSenderItemSize.original.resolution,
                kUTTypeJPEG,
                2
            ),
            (
                ImageURLSenderItemCreatorTest.pngSticker,
                "png",
                .extraLarge,
                ImageSenderItemSize.extraLarge.resolution,
                kUTTypeJPEG,
                2
            ),
            (
                ImageURLSenderItemCreatorTest.pngSticker,
                "png",
                .large,
                ImageSenderItemSize.large.resolution,
                kUTTypeJPEG,
                2
            ),
            (
                ImageURLSenderItemCreatorTest.pngSticker,
                "png",
                .medium,
                ImageSenderItemSize.medium.resolution,
                kUTTypeJPEG,
                2
            ),
            (
                ImageURLSenderItemCreatorTest.pngSticker,
                "png",
                .small,
                ImageSenderItemSize.small.resolution,
                kUTTypeJPEG,
                2
            ),
        ]
        // swiftformat:enable all
        
        let specialTestMatrix = testMatrix[0..<10] + matrix
        
        for item in specialTestMatrix {
            let testImageURL = testBundle.url(forResource: item.0, withExtension: item.1)
            let testImageData = (try? Data(contentsOf: testImageURL!))!
            guard let image = UIImage(data: testImageData) else {
                XCTFail("Could not load image")
                return
            }
            
            let itemCreator = ImageURLSenderItemCreator(with: item.2, forceSize: true)
            
            let senderItem = itemCreator.senderItem(fromImage: image)
            XCTAssert(senderItem!.caption == nil)
            XCTAssert(
                senderItem!.getMimeType() == UTIConverter.mimeType(fromUTI: item.4 as String),
                "\(item.0) had mime type \(senderItem!.getMimeType() ?? "") but expected \(item.4)"
            )
            XCTAssertNotNil(senderItem!.getThumbnail())
        }
    }

    func testCreateSenderFromData() {
        for item in testMatrix {
            let testImageURL = testBundle.url(forResource: item.0, withExtension: item.1)
            let testImageData = (try? Data(contentsOf: testImageURL!))!
            let itemCreator = ImageURLSenderItemCreator(with: item.2, forceSize: true)
            guard let senderItem = itemCreator.senderItem(from: testImageData, uti: item.4 as String) else {
                XCTFail("Could not create senderItem from valid testdata \(testImageURL!)")
                return
            }
            checkSenderItem(senderItem: senderItem, item: item)
        }
    }
    
    func testCreateSenderFromURL() {
        for item in testMatrix {
            let testImageURL = testBundle.url(forResource: item.0, withExtension: item.1)
            let itemCreator = ImageURLSenderItemCreator(with: item.2, forceSize: true)
            guard let senderItem = itemCreator.senderItem(from: testImageURL!) else {
                XCTFail("Could not create senderItem from valid testdata \(String(describing: testImageURL))")
                return
            }
            checkSenderItem(senderItem: senderItem, item: item)
        }
    }
    
    func checkSenderItem(
        senderItem: URLSenderItem,
        item: (String, String, ImageSenderItemSize, CGFloat, CFString, NSNumber)
    ) {
        let testImageURL = testBundle.url(forResource: item.0, withExtension: item.1)
        let testImageData = (try? Data(contentsOf: testImageURL!))!
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
        XCTAssert(
            actualUTI == goldUTI,
            "UTI must be \(String(describing: goldUTI)) but is \(String(describing: actualUTI))"
        )
        XCTAssert(
            senderItem.getHeight() <= height,
            "\(item.0): \(senderItem.getHeight()) should be less than or equal to \(height)"
        )
        XCTAssert(
            senderItem.getWidth() <= width,
            "\(item.0): \(senderItem.getWidth()) should be less than or equal to \(width)"
        )
        XCTAssertNotNil(senderItem.getThumbnail(), "Thumbnail must not be nil")
        XCTAssert(senderItem.renderType! == item.5)
    }
    
    func testAllowedUTITypes() {
        let matrix: [(CFString, Bool)] = [
            (kUTTypePNG, true),
            (kUTTypeGIF, true),
            (kUTTypeJPEG, true),
            (kUTTypeData, false),
            (kUTTypeBMP, false),
            (kUTTypeMP3, false),
        ]
        
        for item in matrix {
            XCTAssert(ImageURLSenderItemCreator.isAllowedUTI(uti: item.0 as String) == item.1)
        }
    }
    
    func testHasAlpha() {
        let testHasAlphaMatrix: [(String, String, ImageSenderItemSize, Bool, Bool)] = [
            (ImageURLSenderItemCreatorTest.pngRegular, "png", .original, false, false),
            (ImageURLSenderItemCreatorTest.pngSticker, "png", .original, true, true),
            (ImageURLSenderItemCreatorTest.pngScreenshot, "png", .original, false, false),
            (ImageURLSenderItemCreatorTest.pngAlpha, "png", .original, true, false),
        ]
        
        for item in testHasAlphaMatrix {
            let testImageURL = testBundle.url(forResource: item.0, withExtension: item.1)
            let testImageData = (try? Data(contentsOf: testImageURL!))!
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
        let urlMatrix: [String] = [
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
