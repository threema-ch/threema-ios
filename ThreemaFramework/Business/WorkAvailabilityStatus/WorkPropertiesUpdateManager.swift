import CocoaLumberjackSwift
import Foundation
import libthreemaSwift
import ThreemaEssentials

final class WorkPropertiesUpdateManager {
    
    // MARK: - Types
    
    enum WorkPropertiesUpdateManagerError: Error {
        case contextCreationFailed
        case missingIdentityInfo
        case missingBaseServerURL
    }
    
    // MARK: - Properties
    
    private let clientInfo: ClientInfo
    private let licenseStore: any LicenseStoreProtocol
    private let serverInfoProvider: any ServerInfoProvider
    private let appFlavorService: any AppFlavorServiceProtocol
    private let myIdentityStore: any MyIdentityStoreProtocol
    private let httpClient: HTTPClient
    
    // MARK: - Lifecycle
    
    init(
        clientInfo: ClientInfo,
        licenseStore: any LicenseStoreProtocol,
        serverInfoProvider: any ServerInfoProvider,
        appFlavorService: any AppFlavorServiceProtocol,
        myIdentityStore: any MyIdentityStoreProtocol,
        httpClient: HTTPClient
    ) {
        self.clientInfo = clientInfo
        self.licenseStore = licenseStore
        self.serverInfoProvider = serverInfoProvider
        self.appFlavorService = appFlavorService
        self.myIdentityStore = myIdentityStore
        self.httpClient = httpClient
    }
    
    // MARK: - Public functions
    
    func updateWorkProperties(workAvailabilityStatus: WorkAvailabilityStatus) async throws {
        // Map to libthreema object
        let category: libthreemaSwift.WorkAvailabilityStatusCategory =
            switch workAvailabilityStatus.category {
            case .none:
                .none
            case .unavailable:
                .unavailable
            case .busy:
                .busy
            }
        
        let availabilityStatus = libthreemaSwift.WorkAvailabilityStatus(
            category: category,
            description: workAvailabilityStatus.text
        )
        let properties = WorkProperties(availabilityStatus: availabilityStatus)
        
        let context = try await createWorkPropertiesUpdateContext()
        let propertiesUpdateTask = try WorkPropertiesUpdateTask(context: context, workProperties: properties)
        
        while true {
            switch try propertiesUpdateTask.poll() {
            case let .instruction(httpsRequest):
                do {
                    let (data, response) = try await httpClient.data(for: httpsRequest.asURLRequest())
                    let httpsResponse = HttpsResponse(data: data, response: response)
                    try propertiesUpdateTask.response(response: .response(httpsResponse))
                }
                catch {
                    DDLogError("[WorkPropertiesUpdateManager] Instruction URL request failed.")
                    try propertiesUpdateTask.response(response: .error(error.asHttpsError()))
                }
                
            case .done:
                DDLogNotice("[WorkPropertiesUpdateManager] Work properties updated.")
                return
            }
        }
    }

    // MARK: - Private functions
    
    private func createWorkPropertiesUpdateContext() async throws -> WorkPropertiesUpdateContext {
        guard let context = workContext() else {
            throw WorkPropertiesUpdateManagerError.contextCreationFailed
        }
        
        guard let identity = myIdentityStore.identity, let clientKey = myIdentityStore.clientKey else {
            throw WorkPropertiesUpdateManagerError.missingIdentityInfo
        }
        
        guard let workServerBaseURL = try await serverInfoProvider.workBaseServerURL() else {
            throw WorkPropertiesUpdateManagerError.missingBaseServerURL
        }
            
        return WorkPropertiesUpdateContext(
            clientInfo: clientInfo,
            // swiftformat:disable:next acronyms
            workServerBaseUrl: workServerBaseURL,
            workContext: context,
            userIdentity: identity,
            clientKey: clientKey
        )
    }
    
    private func workContext() -> WorkContext? {
        guard let username = licenseStore.licenseUsername, let password = licenseStore.licensePassword else {
            return nil
        }
        
        guard appFlavorService.isWork else {
            return nil
        }
        
        let flavor: WorkFlavor = .work
        return WorkContext(credentials: WorkCredentials(username: username, password: password), flavor: flavor)
    }
}
