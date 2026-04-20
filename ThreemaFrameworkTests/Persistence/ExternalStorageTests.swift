import XCTest
@testable import ThreemaFramework

final class ExternalStorageTests: XCTestCase {
    
    func testGetFilenameFromDescription() throws {
        let result = ExternalStorage
            .getFilename(
                description: "External Data Reference: <self = 0x6000028a72a0 ; path = 967F112E-0CBA-40C4-AFDD-60C291509994 ; length = 1893922>"
            )
        
        XCTAssertEqual(result, "967F112E-0CBA-40C4-AFDD-60C291509994")
    }

    func testGetFilenameFromDescriptionNilString() throws {
        let result = ExternalStorage
            .getFilename(
                description: "External Data Reference: <self = 0x6000028a72a0 ; path = nil ; length = 1893922>"
            )
        
        XCTAssertNil(result)
    }

    func testGetFilenameFromDescriptionNoPath() throws {
        let result = ExternalStorage
            .getFilename(
                description: "External Data Reference: <self = 0x6000028a72a0 ; pfad = 967F112E-0CBA-40C4-AFDD-60C291509994 ; length = 1893922>"
            )
        
        XCTAssertNil(result)
    }

    func testGetFilenameFromDescriptionNoEndSemicolon() throws {
        let result = ExternalStorage
            .getFilename(
                description: "External Data Reference: <self = 0x6000028a72a0 ; path = 967F112E-0CBA-40C4-AFDD-60C291509994 / length = 1893922>"
            )
        
        XCTAssertNil(result)
    }

    func testGetFilenameFromDescriptionEmpty() throws {
        let result = ExternalStorage.getFilename(description: "")
        
        XCTAssertNil(result)
    }
}
