import Testing

@Suite("String extension tests")
struct StringTests {
    @Test("Test empty string is empty")
    func emptyString() async throws {
        #expect(String.empty.isEmpty)
    }
}
