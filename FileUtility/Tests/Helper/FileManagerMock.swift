import Foundation

public final class FileManagerMock: FileManager {
    var content = [URL]()

    public var fileExistsCalledWithPath = [String]()

    public init(content: [URL] = [URL]()) {
        self.content = content
    }

    override public func fileExists(atPath path: String) -> Bool {
        fileExistsCalledWithPath.append(path)
        return content.contains(URL(string: path)!)
    }
}
