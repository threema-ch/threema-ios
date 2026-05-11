import Foundation
import ThreemaMacros

public final class RevocationKeyManager {
    
    public static let shared = RevocationKeyManager()
    
    let businessInjector: BusinessInjectorProtocol
    let connector = ServerAPIConnector()

    // MARK: - Lifecycle

    private init(businessInjector: BusinessInjectorProtocol = BusinessInjector()) {
        self.businessInjector = businessInjector
    }
    
    // MARK: - Public func

    public func setPassword(_ password: String) {
        let myIdentityStore = businessInjector.myIdentityStore
        
        connector.setRevocationPassword(password, for: myIdentityStore) {
            myIdentityStore.revocationPasswordLastCheck = nil
            NotificationPresenterWrapper.shared.present(type: .revocationPasswordSuccess)
            NotificationCenter.default.post(name: NSNotification.Name(kRevocationPasswordUIRefresh), object: nil)
        } onError: { _ in
            NotificationPresenterWrapper.shared.present(type: .revocationPasswordError)
            NotificationCenter.default.post(name: NSNotification.Name(kRevocationPasswordUIRefresh), object: nil)
        }
    }
    
    public func checkPasswordSetDate(completion: @escaping () -> Void) {
        let myIdentityStore = businessInjector.myIdentityStore
        
        guard myIdentityStore.revocationPasswordLastCheck == nil else {
            return
        }
        
        connector.checkRevocationPassword(for: myIdentityStore) { _, onDate in
            if let onDate {
                myIdentityStore.revocationPasswordLastCheck = Date.now
                myIdentityStore.revocationPasswordSetDate = onDate
            }
            else {
                myIdentityStore.revocationPasswordLastCheck = nil
                myIdentityStore.revocationPasswordSetDate = nil
            }
            completion()
        } onError: { _ in
            myIdentityStore.revocationPasswordLastCheck = nil
            myIdentityStore.revocationPasswordSetDate = nil
            completion()
        }
    }
}
