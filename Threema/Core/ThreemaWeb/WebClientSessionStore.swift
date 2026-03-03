//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ThreemaFramework

@objc class WebClientSessionStore: NSObject {
    
    @objc static let shared = WebClientSessionStore()
    
    private let entityManager: EntityManager

    override private init() {
        self.entityManager = BusinessInjector.ui.entityManager
    }
    
    @objc func webClientSessionForHash(_ hash: String) -> WebClientSessionEntity? {
        entityManager.entityFetcher.webClientSessionEntity(for: hash)
    }
        
    @objc func activeWebClientSession() -> WebClientSessionEntity? {
        entityManager.entityFetcher.activeWebClientSessionEntity()
    }
    
    @objc func allWebClientSessions() -> [WebClientSessionEntity]? {
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
    
    @objc func updateWebClientSession(session: WebClientSessionEntity, active: Bool) {
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
    
    @objc func setAllWebClientSessionsInactive() {
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
