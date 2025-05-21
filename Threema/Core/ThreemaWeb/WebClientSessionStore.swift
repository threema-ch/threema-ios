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
    
    private var entityManager: EntityManager?

    override private init() {
        self.entityManager = EntityManager()
    }
    
    @objc func webClientSessionForHash(_ hash: String) -> WebClientSessionEntity? {
        entityManager!.entityFetcher.webClientSessionEntity(forInitiatorPermanentPublicKeyHash: hash)
    }
        
    @objc func activeWebClientSession() -> WebClientSessionEntity? {
        entityManager!.entityFetcher.activeWebClientSessionEntity()
    }
    
    @objc func allWebClientSessions() -> [WebClientSessionEntity]? {
        entityManager!.entityFetcher.allWebClientSessions() as? [WebClientSessionEntity]
    }
    
    func addWebClientSession(dictionary: [String: Any]) -> WebClientSessionEntity {
        var session: WebClientSessionEntity?
        
        if let hash = dictionary["initiatorPermanentPublicKeyHash"] as? String {
            session = entityManager!.entityFetcher.webClientSessionEntity(forInitiatorPermanentPublicKeyHash: hash)
        }
        
        if session != nil {
            return session!
        }
        
        entityManager!.performAndWaitSave {
            session = self.entityManager!.entityCreator.webClientSessionEntity()
            session!.permanent = NSNumber(value: dictionary["permanent"] as! Bool) as NSNumber
            session!.saltyRTCHost = dictionary["saltyRTCHost"] as! String
            session!.initiatorPermanentPublicKey = dictionary["initiatorPermanentPublicKey"] as! Data
            session!.serverPermanentPublicKey = dictionary["serverPermanentPublicKey"] as! Data
            session!.saltyRTCPort = (dictionary["saltyRTCPort"] as? NSNumber)!
            session!.version = dictionary["webClientVersion"] as? NSNumber
            session!.selfHosted = NSNumber(value: dictionary["selfHosted"] as! Bool) as NSNumber
            
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
        entityManager!.performAndWaitSave {
            session.active = NSNumber(value: active) as NSNumber
        }
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, privateKey: Data?) {
        entityManager!.performAndWaitSave {
            session.privateKey = privateKey
        }
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, hash: String) {
        entityManager!.performAndWaitSave {
            session.initiatorPermanentPublicKeyHash = hash
        }
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, lastConnection: Date) {
        entityManager!.performAndWaitSave {
            session.lastConnection = lastConnection
        }
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, browserName: String, browserVersion: NSNumber) {
        entityManager!.performAndWaitSave {
            session.browserName = browserName
            session.browserVersion = browserVersion
        }
    }
    
    func updateWebClientSession(session: WebClientSessionEntity, sessionName: String?) {
        entityManager!.performAndWaitSave {
            session.name = sessionName
        }
    }
    
    func deleteAllWebClientSessions() {
        entityManager!.performAndWaitSave {
            let sessions = self.entityManager!.entityFetcher.allWebClientSessions() as? [WebClientSessionEntity]
            if sessions != nil {
                for session in sessions! {
                    self.entityManager?.entityDestroyer.delete(webClientSessionEntity: session)
                }
            }
        }
    }
    
    func deleteWebClientSession(_ session: WebClientSessionEntity) {
        entityManager!.performAndWaitSave {
            self.entityManager?.entityDestroyer.delete(webClientSessionEntity: session)
        }
    }
    
    @objc func setAllWebClientSessionsInactive() {
        entityManager!.performAndWaitSave {
            let sessions = self.entityManager!.entityFetcher.allActiveWebClientSessions() as? [WebClientSessionEntity]
            if sessions != nil {
                for session: WebClientSessionEntity in sessions! {
                    session.active = NSNumber(value: false) as NSNumber
                }
            }
        }
    }
        
    func removeAllNotPermanentSessions() {
        entityManager!.performAndWaitSave {
            let sessions = self.entityManager!.entityFetcher
                .allNotPermanentWebClientSessions() as? [WebClientSessionEntity]
            if sessions != nil {
                for session in sessions! {
                    self.entityManager?.entityDestroyer.delete(webClientSessionEntity: session)
                }
            }
        }
    }
}
