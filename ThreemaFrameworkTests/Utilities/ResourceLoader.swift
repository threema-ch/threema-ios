import Foundation

final class ResourceLoader {
    
    static func urlResource(_ filename: String, _ fileExtension: String) -> URL? {
        let testBundle = Bundle(for: ResourceLoader.self)
        return testBundle.url(forResource: filename, withExtension: fileExtension)
    }
    
    static func contentAsString(_ fileName: String, _ fileExtension: String) -> String? {
        let testBundle = Bundle(for: ResourceLoader.self)
        if let filePath = testBundle.path(forResource: fileName, ofType: fileExtension) {
            return try? String(contentsOfFile: filePath, encoding: .utf8)
        }
        return nil
    }
}
