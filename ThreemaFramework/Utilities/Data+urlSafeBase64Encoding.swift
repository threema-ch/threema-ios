import Foundation

/// Extend `Data` with URL safe Base64 encoding according to RFC 3548
///
/// https://www.rfc-editor.org/rfc/rfc3548#section-4
extension Data {
    /// New data from URL safe Base64 encoded string
    /// - Parameters:
    ///   - urlSafeBase64Encoded: URL safe Base64 encoded string
    ///   - options: Same options as vended Base64 functionality
    init?(urlSafeBase64Encoded: String, options: Data.Base64DecodingOptions = []) {
        let base64String = urlSafeBase64Encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        self.init(base64Encoded: base64String, options: options)
    }
    
    /// Create URL safe Base64 encoded string from data
    /// - Parameter options: Same options as vended Base64 functionality
    /// - Returns: URL safe Base64 encoded string
    func urlSafeBase64EncodedString(options: Data.Base64EncodingOptions = []) -> String {
        let base64String = base64EncodedString(options: options)
        let urlSafeBase64String = base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        
        return urlSafeBase64String
    }
}
