import Testing
@testable import ThreemaFramework

struct DarwinNotificationCenterTests {
    @Test func testDarwinNotificationObservePost() async throws {
        let expectedName = DarwinNotificationName("test-comunication")

        let name: DarwinNotificationName = await withCheckedContinuation { continuation in
            DarwinNotificationCenter.shared.addObserver(name: expectedName) { name in
                continuation.resume(returning: name)
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(30)) {
                DarwinNotificationCenter.shared.post(expectedName)
            }
        }

        #expect(name == expectedName)

        DarwinNotificationCenter.shared.removeObserver(name: expectedName)
    }
}
