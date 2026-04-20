import Testing
@testable import Threema

@Suite @MainActor struct ZipFileUIActivityItemProviderTests {

    @Test("Processing of a ZipFileUIActivityItemProvider")
    func zip() throws {

        // ARRANGE
        let url = anyURL()
        let sut = ZipFileUIActivityItemProvider(url: url, subject: "Subject")
        let vc = UIActivityViewController(activityItems: [], applicationActivities: [])

        // ACT
        let subject = sut.activityViewController(vc, subjectForActivityType: nil)
        let identifier = sut.activityViewController(vc, dataTypeIdentifierForActivityType: nil)

        // ASSERT
        #expect((sut.item as? URL) == url)
        #expect(subject == "Subject")
        #expect(identifier == "com.pkware.zip-archive")
    }

    // MARK: Helpers

    private func anyURL() -> URL {
        URL(string: "https://www.abc.com")!
    }
}
