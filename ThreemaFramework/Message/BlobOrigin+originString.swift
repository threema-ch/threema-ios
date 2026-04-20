import Foundation

extension BlobOrigin {
    var originString: String {
        switch self {
        case .public:
            return "public"
        case .local:
            return "local"
        @unknown default:
            fatalError("[BlobOrigin] Unknown case")
        }
    }
}
