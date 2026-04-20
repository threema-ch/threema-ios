import FileUtility
import Foundation

public final class FileManagerResolverMock: FileManagerResolverProtocol {
    let fileManagerMock: FileManagerMock

    public init(fileManagerMock: FileManagerMock = FileManagerMock()) {
        self.fileManagerMock = fileManagerMock
    }

    public var fileManager: FileManager {
        fileManagerMock
    }
}
