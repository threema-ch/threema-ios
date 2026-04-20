import Combine
import Contacts
import ThreemaFramework
import ThreemaMacros

final class ContactPreviewViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var showAlert = false
    
    let fileMessageEntity: FileMessageEntity
    let authorizationStatus: (CNEntityType) -> CNAuthorizationStatus
    let requestContactAccess: (CNEntityType) async throws -> Bool
    
    private(set) lazy var alertTitle = #localize("alert_no_access_title_contacts")
    private(set) lazy var alertMessage = #localize("alert_no_access_message_contacts")
    private(set) lazy var alertOpenSettingsButtonTitle = #localize("alert_no_access_open_settings")
    private(set) lazy var alertCancelButtonTitle = #localize("cancel")

    init(
        fileMessageEntity: FileMessageEntity,
        authorizationStatus: @escaping (CNEntityType) -> CNAuthorizationStatus,
        requestContactAccess: @escaping (CNEntityType) async throws -> Bool
    ) {
        self.fileMessageEntity = fileMessageEntity
        self.authorizationStatus = authorizationStatus
        self.requestContactAccess = requestContactAccess
    }

    func checkContactAccess() {
        let status = authorizationStatus(.contacts)

        if #available(iOS 18.0, *) {
            isAuthorized = status == .authorized || status == .limited
        }
        else {
            isAuthorized = status == .authorized
        }

        guard !isAuthorized else {
            return
        }
        
        Task { [weak self] in
            guard let self else {
                return
            }
            
            do {
                let granted = try await requestContactAccess(.contacts)
                
                if granted {
                    isAuthorized = true
                }
                else {
                    showAlert = true
                }
            }
            catch {
                showAlert = true
            }
        }
    }
    
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        UIApplication.shared.open(url)
    }
}
