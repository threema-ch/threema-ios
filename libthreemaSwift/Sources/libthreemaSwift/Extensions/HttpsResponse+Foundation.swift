import Foundation

extension HttpsResponse {
    public init(data: Data, response: HTTPURLResponse) {
        self.init(status: UInt16(response.statusCode), body: data)
    }
}
