import FileUtilityTestHelper
import Foundation
import Testing
@testable import FileUtility

struct FileUtilityTests {

    @Test
    func testFileExists() {
        let fileManagerMock = FileManagerMock(
            content: [URL(string: "/test/123")!]
        )

        let fileUtility = FileUtility(
            resolver: FileManagerResolverMock(
                fileManagerMock: fileManagerMock
            )
        )

        let result = fileUtility.fileExists(at: URL(string: "/test/123"))

        #expect(result == true)
        #expect(
            fileManagerMock.fileExistsCalledWithPath.contains(
                "/test/123"
            ) == true
        )
    }
}
