import CocoaLumberjackSwift
import Foundation

extension URL {
    var getQueries: [String: String] {
        
        func decodingURLFormat(string: String) -> String {
            var result = string.replacingOccurrences(of: "+", with: " ")
            result = result.removingPercentEncoding ?? ""
            return result
        }
        
        var dict: [String: String] = [:]
        let items = URLComponents(string: absoluteString)?.queryItems ?? []
        for item in items {
            dict.updateValue(
                decodingURLFormat(string: item.value ?? ""),
                forKey: decodingURLFormat(string: item.name)
            )
        }
        return dict
    }
}
