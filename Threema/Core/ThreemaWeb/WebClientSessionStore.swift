import Foundation
import ThreemaFramework

final class WebClientSessionStore {
    
    static let shared = WebClientSessionStore()
    
    private let entityManager: EntityManager

    init() {
        self.entityManager = BusinessInjector.ui.entityManager
    }
    
    func webClientSessionForHash(_ hash: String) -> WebClientSessionEntity? {
        entityManager.entityFetcher.webClientSessionEntity(for: hash)
    }
        
    func activeWebClientSession() -> WebClientSessionEntity? {
        entityManager.entityFetcher.activeWebClientSessionEntity()
    }
    
    func allWebClientSessions() -> [WebClientSessionEntity]? {
        entityManager.entityFetcher.webClientSessionEntities()
    }
    
    func addWebClientSession(dictionary: [String: Any]) -> WebClientSessionEntity {
        var session: WebClientSessionEntity?
        
        if let hash = dictionary["initiatorPermanentPublicKeyHash"] as? String {
            session = entityManager.entityFetcher.webClientSessionEntity(for: hash)
        }
        
        if let session {
            return session
        }
        
        entityManager.performAndWaitSave {
            session = self.entityManager.entityCreator.webClientSessionEntity(
                initiatorPermanentPublicKey: dictionary["initiatorPermanentPublicKey"] as! Data,
                permanent: dictionary["permanent"] as! Bool,
                saltyRTCHost: dictionary["saltyRTCHost"] as! String,
                saltyRTCPort: Int64(dictionary["saltyRTCPort"] as! Int),
                selfHosted: dictionary["selfHosted"] as! Bool,
                serverPermanentPublicKey: dictionary["serverPermanentPublicKey"] as! Data
            )
   
            session!.version = dictionary["webClientVersion"] as? NSNumber
            
            if let lastConnection = dictionary["lastConnection"] as? Date {
                session!.lastConnection = lastConnection
            }
            
            if let initiatorPermanentPublicKeyHash = dictionary["initiatorPermanentPublicKeyHash"] as? String {
                session!.initiatorPermanentPublicKeyHash = initiatorPermanentPublicKeyHash
            }
            
            if let privateKey = dictionary["privateKey"] as? Data {
                session!.privateKey = privateKey
            }
            
            if let browserName = dictionary["browserName"] as? String {
                session!.browserName = browserName
            }
            
            if let browserVersion = dictionary["browserVersion"] as? NSNumber {
                session!.browserVersion = browserVersion
            }
            
            if let active = dictionary["active"] as? Bool {
                session!.active = NSNumber(value: active) as NSNumber
            }
        }
        return session!
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, active: Bool) {
        entityManager.performAndWaitSave {
            session.active = NSNumber(value: active) as NSNumber
        }
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, privateKey: Data?) {
        entityManager.performAndWaitSave {
            session.privateKey = privateKey
        }
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, hash: String) {
        entityManager.performAndWaitSave {
            session.initiatorPermanentPublicKeyHash = hash
        }
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, lastConnection: Date) {
        entityManager.performAndWaitSave {
            session.lastConnection = lastConnection
        }
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, browserName: String, browserVersion: NSNumber) {
        entityManager.performAndWaitSave {
            session.browserName = browserName
            session.browserVersion = browserVersion
        }
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, sessionName: String?) {
        entityManager.performAndWaitSave {
            session.name = sessionName
        }
    }
    
    func deleteAllWebClientSessions() {
        entityManager.performAndWaitSave {
            if let sessions = self.entityManager.entityFetcher.webClientSessionEntities() {
                for session in sessions {
                    self.entityManager.entityDestroyer.delete(webClientSessionEntity: session)
                }
            }
        }
    }
    
    func deleteWebClientSession(_ session: WebClientSessionEntity) {
        entityManager.performAndWaitSave {
            self.entityManager.entityDestroyer.delete(webClientSessionEntity: session)
        }
    }
    
    func setAllWebClientSessionsInactive() {
        entityManager.performAndWaitSave {
            if let sessions = self.entityManager.entityFetcher.activeWebClientSessionEntities() {
                for session in sessions {
                    session.active = NSNumber(value: false) as NSNumber
                }
            }
        }
    }
        
    func removeAllNotPermanentSessions() {
        entityManager.performAndWaitSave {
            if let sessions = self.entityManager.entityFetcher
                .notPermanentWebClientSessionEntities() {
                for session in sessions {
                    self.entityManager.entityDestroyer.delete(webClientSessionEntity: session)
                }
            }
        }
    }
}
