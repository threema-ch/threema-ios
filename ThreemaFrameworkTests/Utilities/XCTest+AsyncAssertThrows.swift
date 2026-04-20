import Foundation
import XCTest

extension XCTest {
    func XCTAssertThrowsAsyncError(
        _ expression: @autoclosure () async throws -> some Sendable,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail(message(), file: file, line: line)
        }
        catch {
            errorHandler(error)
        }
    }
}
