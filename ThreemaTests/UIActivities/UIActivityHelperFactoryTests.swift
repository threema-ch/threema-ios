import Testing
import UniformTypeIdentifiers
@testable import Threema

@Suite @MainActor struct UIActivityHelperFactoryTests {

    @Test("Creation of an zip activity activity item provider")
    func zip() throws {

        // ARRANGE
        let sut = UIActivityHelperFactory.self

        // ACT
        let itemSource = sut.makeItemSource(type: .zipFile(url: anyURL(), subject: "Subject"))

        // ASSERT
        guard itemSource is ZipFileUIActivityItemProvider else {
            let expected = String(describing: ZipFileUIActivityItemProvider.self)
            let actual = String(describing: itemSource)
            Issue.record("Expected \(expected) instance, got \(actual) instead.")
            return
        }
    }

    @Test("Creation of an forward URLs UI activity")
    func forwardURLs() throws {

        // ARRANGE
        let sut = UIActivityHelperFactory.self

        // ACT
        let itemSource = sut.makeActivity(type: .forwardURLs)

        // ASSERT
        guard itemSource is ForwardURLsUIActivity else {
            let expected = String(describing: ForwardURLsUIActivity.self)
            let actual = String(describing: itemSource)
            Issue.record("Expected \(expected) instance, got \(actual) instead.")
            return
        }
    }

    @Test("Creation of a message activity source item")
    func messageActivity() throws {

        // ARRANGE
        let sut = UIActivityHelperFactory.self

        // ACT
        let itemSource = sut.makeItemSource(
            type: .messageActivity(
                .init(
                    type: .text("Text"),
                    dataTypeIdentifier: "identifier",
                    exportURL: URL(fileURLWithPath: NSTemporaryDirectory())
                )
            )
        )

        // ASSERT
        guard itemSource is MessageUIActivityItemSource else {
            let expected = String(describing: MessageUIActivityItemSource.self)
            let actual = String(describing: itemSource)
            Issue.record("Expected \(expected) instance, got \(actual) instead.")
            return
        }
    }

    // MARK: Helpers

    private func anyURL() -> URL {
        URL(string: "https://www.abc.com")!
    }
}
