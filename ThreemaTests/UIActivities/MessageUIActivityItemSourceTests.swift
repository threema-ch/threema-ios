import FileUtility
import Testing
import UniformTypeIdentifiers

@testable import Threema

@Suite @MainActor struct MessageUIActivityItemSourceTests {

    @Test("Processing a MessageUIActivityItemSource with a text message")
    func textMessage() async throws {
        // ARRANGE
        let message = "Text message"
        let exportURL = try makeURL(string: #function)
        let identifier = UTType.plainText.identifier

        try? FileManager.default.removeItem(at: exportURL)

        let content = MessageUIActivityItemSource.MessageShareContent(
            type: .text(message),
            dataTypeIdentifier: identifier,
            exportURL: exportURL
        )

        let vc = UIActivityViewController(activityItems: [], applicationActivities: [])

        let sut = makeSUT(for: content)

        #expect(FileManager.default.fileExists(atPath: exportURL.path) == false)

        // ACT

        let placeholderItem = sut.activityViewControllerPlaceholderItem(vc)
        let item = sut.activityViewController(vc, itemForActivityType: nil)
        let type = sut.activityViewController(vc, dataTypeIdentifierForActivityType: nil)

        // ASSERT

        #expect(placeholderItem as? String == message)
        #expect(item as? String == message)
        #expect(type == identifier)
        #expect(FileManager.default.fileExists(atPath: exportURL.path) == false)
    }

    @Test("Processing a MessageUIActivityItemSource with an audio message")
    func audioMessage() async throws {
        // ARRANGE
        let exportURL = try makeURL(string: #function)
        let identifier = UTType.audio.identifier

        try? FileManager.default.removeItem(at: exportURL)

        let data = Data(repeating: 1, count: 100)

        let content = MessageUIActivityItemSource.MessageShareContent(
            type: .audio(data),
            dataTypeIdentifier: identifier,
            exportURL: exportURL
        )

        let vc = UIActivityViewController(activityItems: [], applicationActivities: [])

        let sut = makeSUT(for: content)

        #expect(FileManager.default.fileExists(atPath: exportURL.path) == false)

        // ACT

        let placeholderItem = sut.activityViewControllerPlaceholderItem(vc)
        let item = sut.activityViewController(vc, itemForActivityType: nil)
        let type = sut.activityViewController(vc, dataTypeIdentifierForActivityType: nil)

        // ASSERT

        #expect(placeholderItem as? URL == exportURL)
        #expect(item as? URL == exportURL)
        #expect(type == identifier)
        #expect(FileManager.default.contents(atPath: exportURL.path) == data)
    }

    @Test("Processing a MessageUIActivityItemSource with an image message")
    func imageMessage() async throws {
        // ARRANGE
        let exportURL = try makeURL(string: #function)
        let identifier = UTType.image.identifier

        try? FileManager.default.removeItem(at: exportURL)

        let data = Data(repeating: 1, count: 100)

        let content = MessageUIActivityItemSource.MessageShareContent(
            type: .image(data),
            dataTypeIdentifier: identifier,
            exportURL: exportURL
        )

        let vc = UIActivityViewController(activityItems: [], applicationActivities: [])

        let sut = makeSUT(for: content)

        #expect(FileManager.default.fileExists(atPath: exportURL.path) == false)

        // ACT

        let placeholderItem = sut.activityViewControllerPlaceholderItem(vc)
        let item = sut.activityViewController(vc, itemForActivityType: nil)
        let type = sut.activityViewController(vc, dataTypeIdentifierForActivityType: nil)

        // ASSERT

        #expect(placeholderItem as? URL == exportURL)
        #expect(item as? URL == exportURL)
        #expect(type == identifier)
        #expect(FileManager.default.contents(atPath: exportURL.path) == data)
    }

    @Test("Processing a MessageUIActivityItemSource with a video message")
    func videoMessage() async throws {
        // ARRANGE
        let exportURL = try makeURL(string: #function)
        let identifier = UTType.video.identifier

        try? FileManager.default.removeItem(at: exportURL)

        let data = Data(repeating: 1, count: 100)

        let content = MessageUIActivityItemSource.MessageShareContent(
            type: .video(data),
            dataTypeIdentifier: identifier,
            exportURL: exportURL
        )

        let vc = UIActivityViewController(activityItems: [], applicationActivities: [])

        let sut = makeSUT(for: content)

        #expect(FileManager.default.fileExists(atPath: exportURL.path) == false)

        // ACT

        let placeholderItem = sut.activityViewControllerPlaceholderItem(vc)
        let item = sut.activityViewController(vc, itemForActivityType: nil)
        let type = sut.activityViewController(vc, dataTypeIdentifierForActivityType: nil)

        // ASSERT

        #expect(placeholderItem as? URL == exportURL)
        #expect(item as? URL == exportURL)
        #expect(type == identifier)
        #expect(FileManager.default.contents(atPath: exportURL.path) == data)
    }

    @Test("Processing a MessageUIActivityItemSource with a file message and no activity type")
    func fileMessageRegularActivityType() async throws {
        // ARRANGE
        let exportURL = try makeURL(string: #function)
        let identifier = UTType.data.identifier

        try? FileManager.default.removeItem(at: exportURL)

        let data = Data(repeating: 1, count: 100)

        let content = MessageUIActivityItemSource.MessageShareContent(
            type: .file(data, renderType: 0),
            dataTypeIdentifier: identifier,
            exportURL: exportURL
        )

        let vc = UIActivityViewController(activityItems: [], applicationActivities: [])

        let sut = makeSUT(for: content)

        #expect(FileManager.default.fileExists(atPath: exportURL.path) == false)

        // ACT

        let placeholderItem = sut.activityViewControllerPlaceholderItem(vc)
        let item = sut.activityViewController(vc, itemForActivityType: nil)
        let type = sut.activityViewController(vc, dataTypeIdentifierForActivityType: nil)

        // ASSERT

        #expect(placeholderItem as? URL == exportURL)
        #expect(item as? URL == exportURL)
        #expect(type == identifier)
        #expect(FileManager.default.contents(atPath: exportURL.path) == data)
    }

    @Test("Processing a MessageUIActivityItemSource with a file message and forward activity type")
    func fileMessageForwardActivityType() async throws {
        // ARRANGE
        let exportURL = try makeURL(string: #function)
        let identifier = UTType.data.identifier
        let activityType = UIActivity.ActivityType("ch.threema.iapp.forwardMsg")
        let renderType = 5

        try? FileManager.default.removeItem(at: exportURL)

        let data = Data(repeating: 1, count: 100)

        let content = MessageUIActivityItemSource.MessageShareContent(
            type: .file(data, renderType: renderType),
            dataTypeIdentifier: identifier,
            exportURL: exportURL
        )

        let vc = UIActivityViewController(activityItems: [], applicationActivities: [])

        let sut = makeSUT(for: content)

        #expect(FileManager.default.fileExists(atPath: exportURL.path) == false)

        // ACT

        let placeholderItem = sut.activityViewControllerPlaceholderItem(vc)
        let item = sut.activityViewController(vc, itemForActivityType: activityType)
        let type = sut.activityViewController(vc, dataTypeIdentifierForActivityType: activityType)

        // ASSERT

        guard let dictionaryItem = item as? [String: Any] else {
            Issue.record("Expected a dictionary item but got \(String(describing: item)) instead.")
            return
        }

        #expect(placeholderItem as? URL == exportURL)
        #expect(dictionaryItem["url"] as? URL == exportURL)
        #expect(dictionaryItem["renderType"] as? Int == renderType)
        #expect(type == identifier)
        #expect(FileManager.default.contents(atPath: exportURL.path) == data)
    }

    // MARK: - Helpers

    private func makeSUT(
        for content: MessageUIActivityItemSource.MessageShareContent
    ) -> MessageUIActivityItemSource {
        MessageUIActivityItemSource(
            content: content,
            fileUtility: FileUtility()
        )
    }
    
    private func makeURL(string: String) throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(string)
    }
}
