import libthreemaSwift
import RemoteSecretProtocol

enum RemoteSecretHelper {
    static func runHTTPSRequest(
        _ httpsRequest: HttpsRequest,
        httpClient: any RemoteSecretHTTPClientProtocol
    ) async -> HttpsResult {
        do {
            let (data, response) = try await httpClient.data(for: httpsRequest.asURLRequest())
            let httpsResponse = HttpsResponse(data: data, response: response)
            return .response(httpsResponse)
        }
        catch {
            return .error(error.asHttpsError())
        }
    }
}
