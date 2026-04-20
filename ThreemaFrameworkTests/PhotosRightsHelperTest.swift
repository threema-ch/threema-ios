import XCTest
@testable import ThreemaFramework

final class PhotosRightsHelperTest: XCTestCase {

    func testPhotosRights() throws {
        let table: [([Bool], PhotosRights)] = [
            ([true, true, true, true, true, true], .full),
            ([false, true, true, true, true, true], .write),
            ([false, false, false, true, true, true], .none),
        ]
        
        var mock: PhotosRightsHelperMock
        
        for item in table {
            mock = PhotosRightsHelperMock(
                accessLevelDetermined: item.0[0],
                requestWriteAccess: item.0[1],
                requestReadAccess: item.0[2],
                readAccess: item.0[3],
                fullAccess: item.0[4],
                writeAccess: item.0[5]
            )
            let result = PhotosRightsHelper.checkAccessAllowed(rightsHelper: mock)
            XCTAssert(result == item.1, "Result is \(result), but should be \(item.1). For input \(item)")
        }
    }
}
