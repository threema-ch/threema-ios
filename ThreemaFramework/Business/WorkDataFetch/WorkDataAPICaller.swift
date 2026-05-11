import Foundation

public final class WorkDataAPICaller: WorkDataAPICallerProtocol {
    
    // MARK: - Private properties

    private let username: String?
    private let password: String?
    private let serverAPIRequest: any ServerAPIRequestProtocol

    private let path = "fetch2"
    
    // MARK: - Lifecycle

    public init(
        username: String?,
        password: String?,
        serverAPIRequest: any ServerAPIRequestProtocol = ServerAPIRequestAdapter()
    ) {
        self.username = username
        self.password = password
        self.serverAPIRequest = serverAPIRequest
    }
    
    public convenience init(licenseStore: LicenseStoreProtocol) {
        self.init(username: licenseStore.licenseUsername, password: licenseStore.licensePassword)
    }
    
    // MARK: - WorkDataAPICallerProtocol

    public func fetchWorkData(with contacts: [String]) async throws -> Data {
        
        guard let username,
              let password else {
            throw WorkDataFetchError.missingCredentials
        }
        
        let requestData: [String: Any] = [
            "username": username,
            "password": password,
            "contacts": contacts,
        ]
        
        let json = try await serverAPIRequest.postJSONToWorkAPI(path: path, data: requestData)
        
        guard let json else {
            throw WorkDataFetchError.invalidResponse
        }
        
        return try JSONSerialization.data(withJSONObject: json)
    }
}
