//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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
    
    private var entityManager: EntityManager? = nil

    private override init() {
        entityManager = EntityManager()
    }
    
    @objc func webClientSessionForHash(_ hash: String) -> WebClientSession? {
        return entityManager!.entityFetcher.webClientSession(forInitiatorPermanentPublicKeyHash: hash)
    }
        
    @objc func activeWebClientSession() -> WebClientSession? {
        return entityManager!.entityFetcher.activeWebClientSession()
    }
    
    @objc func allWebClientSessions() -> [WebClientSession]? {
        return entityManager!.entityFetcher.allWebClientSessions() as? [WebClientSession]
    }
    
    func addWebClientSession(dictionary: [String: Any]) -> WebClientSession {
        var session: WebClientSession? = nil
        
        if let hash = dictionary["initiatorPermanentPublicKeyHash"] as? String {
            session = entityManager!.entityFetcher.webClientSession(forInitiatorPermanentPublicKeyHash: hash)
        }
        
        if session != nil {
            return session!
        }
        
        entityManager!.performSyncBlockAndSafe {
            session = self.entityManager!.entityCreator.webClientSession()
            session!.permanent = NSNumber.init(value: dictionary["permanent"] as! Bool) as NSNumber
            session!.saltyRTCHost = dictionary["saltyRTCHost"] as? String
            session!.initiatorPermanentPublicKey = dictionary["initiatorPermanentPublicKey"] as? Data
            session!.serverPermanentPublicKey = dictionary["serverPermanentPublicKey"] as? Data
            session!.saltyRTCPort = dictionary["saltyRTCPort"] as? NSNumber
            session!.version = dictionary["webClientVersion"] as? NSNumber
            session!.selfHosted = NSNumber.init(value: dictionary["selfHosted"] as! Bool) as NSNumber
            
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
                session!.active = NSNumber.init(value: active) as NSNumber
            }
        }
        return session!
    }
    
    @objc func updateWebClientSession(session: WebClientSession, active: Bool) {
        entityManager!.performSyncBlockAndSafe {
            session.active = NSNumber.init(value: active) as NSNumber
        }
    }
    
    func updateWebClientSession(session: WebClientSession, privateKey: Data?) {
        entityManager!.performSyncBlockAndSafe {
            session.privateKey = privateKey
        }
    }
    
    func updateWebClientSession(session: WebClientSession, hash: String) {
        entityManager!.performSyncBlockAndSafe {
            session.initiatorPermanentPublicKeyHash = hash
        }
    }
    
    func updateWebClientSession(session: WebClientSession, lastConnection: Date) {
        entityManager!.performSyncBlockAndSafe {
            session.lastConnection = lastConnection
        }
    }
    
    func updateWebClientSession(session: WebClientSession, browserName: String!, browserVersion: NSNumber!) {
        entityManager!.performSyncBlockAndSafe {
            session.browserName = browserName
            session.browserVersion = browserVersion
        }
    }
    
    func updateWebClientSession(session: WebClientSession, sessionName: String?) {
        entityManager!.performSyncBlockAndSafe {
            session.name = sessionName
        }
    }
    
    func deleteAllWebClientSessions() {
        entityManager!.performSyncBlockAndSafe {
            let sessions = self.entityManager!.entityFetcher.allWebClientSessions() as? [WebClientSession]
            if sessions != nil {
                for session in sessions! {
                    self.entityManager?.entityDestroyer.deleteObject(object: session)
                }
            }
        }
    }
    
    func deleteWebClientSession(_ session: WebClientSession) {
        entityManager!.performSyncBlockAndSafe {
            self.entityManager?.entityDestroyer.deleteObject(object: session)
        }
    }
    
    @objc func setAllWebClientSessionsInactive() {
        entityManager!.performSyncBlockAndSafe {
            let sessions = self.entityManager!.entityFetcher.allActiveWebClientSessions() as? [WebClientSession]
            if sessions != nil {
                for session: WebClientSession in sessions! {
                    session.active = NSNumber.init(value: false) as NSNumber
                }
            }
        }
    }
        
    func removeAllNotPermanentSessions() {
        entityManager!.performSyncBlockAndSafe {
            let sessions = self.entityManager!.entityFetcher.allNotPermanentWebClientSessions() as? [WebClientSession]
            if sessions != nil {
                for session in sessions! {
                    self.entityManager?.entityDestroyer.deleteObject(object: session)
                }
            }
        }
    }
}
