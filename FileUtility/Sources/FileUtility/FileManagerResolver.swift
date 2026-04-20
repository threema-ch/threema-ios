import Foundation

public protocol FileManagerResolverProtocol {
    var fileManager: FileManager { get }
}

final class FileManagerResolver: FileManagerResolverProtocol {
    var fileManager: FileManager { .default }
}
