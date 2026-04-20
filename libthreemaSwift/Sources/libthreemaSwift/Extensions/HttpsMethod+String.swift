import Foundation

extension HttpsMethod {
    public var string: String {
        switch self {
        case .delete:
            "DELETE"
        case .get:
            "GET"
        case .post:
            "POST"
        case .put:
            "PUT"
        }
    }
}
