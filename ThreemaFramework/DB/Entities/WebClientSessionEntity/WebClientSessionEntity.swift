//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import CoreData
import Foundation

@objc(WebClientSessionEntity)
public final class WebClientSessionEntity: TMAManagedObject {
    
    // Attributes
    @NSManaged @objc(active) public var active: NSNumber?
    @NSManaged @objc(browserName) public var browserName: String?
    @NSManaged @objc(browserVersion) public var browserVersion: NSNumber?
    @NSManaged @objc(initiatorPermanentPublicKey) public var initiatorPermanentPublicKey: Data
    @NSManaged @objc(initiatorPermanentPublicKeyHash) public var initiatorPermanentPublicKeyHash: String?
    @NSManaged @objc(lastConnection) public var lastConnection: Date?
    @NSManaged @objc(name) public var name: String?
    @NSManaged @objc(permanent) public var permanent: NSNumber
    @NSManaged @objc(privateKey) public var privateKey: Data?
    @NSManaged @objc(saltyRTCHost) public var saltyRTCHost: String
    @NSManaged @objc(saltyRTCPort) public var saltyRTCPort: NSNumber
    @NSManaged @objc(selfHosted) public var selfHosted: NSNumber
    @NSManaged @objc(serverPermanentPublicKey) public var serverPermanentPublicKey: Data
    @NSManaged @objc(version) public var version: NSNumber?

    // Non-CoreData Properties
    @objc public var isConnecting = false
    
    // Lifecycle
    
    // TODO: (IOS-4752) Use in EntityCreator/DB Preparer
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - active: True if the session active
    ///   - browserName: Name of the browser
    ///   - browserVersion: Version of the browser
    ///   - initiatorPermanentPublicKey: Public key of the initiator
    ///   - initiatorPermanentPublicKeyHash: Hash of the public key of the initiator
    ///   - lastConnection: Date of the last connection
    ///   - name: Name of the session
    ///   - permanent: True if session is permanent
    ///   - privateKey: Private key of the session
    ///   - saltyRTCHost: SaltyRTC host
    ///   - saltyRTCPort: SaltyRTC port
    ///   - selfHosted: True if is self hosted
    ///   - serverPermanentPublicKey: Public key of the server
    ///   - version: Version number
    public init(
        context: NSManagedObjectContext,
        active: Bool? = nil,
        browserName: String? = nil,
        browserVersion: Int32? = nil,
        initiatorPermanentPublicKey: Data,
        initiatorPermanentPublicKeyHash: String? = nil,
        lastConnection: Date? = nil,
        name: String? = nil,
        permanent: Bool,
        privateKey: Data? = nil,
        saltyRTCHost: String,
        saltyRTCPort: Int64,
        selfHosted: Bool,
        serverPermanentPublicKey: Data,
        version: Int32? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "WebClientSession", in: context)!
        super.init(entity: entity, insertInto: context)
        
        if let active {
            self.active = NSNumber(booleanLiteral: active)
        }
        self.browserName = browserName
        if let browserVersion {
            self.browserVersion = browserVersion as NSNumber
        }
        self.initiatorPermanentPublicKey = initiatorPermanentPublicKey
        self.initiatorPermanentPublicKeyHash = initiatorPermanentPublicKeyHash
        self.lastConnection = lastConnection
        self.name = name
        self.permanent = NSNumber(booleanLiteral: permanent)
        self.privateKey = privateKey
        self.saltyRTCHost = saltyRTCHost
        self.saltyRTCPort = saltyRTCPort as NSNumber
        self.selfHosted = NSNumber(booleanLiteral: selfHosted)
        self.serverPermanentPublicKey = serverPermanentPublicKey
        if let version {
            self.version = version as NSNumber
        }
    }
    
    @objc override private init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    @available(*, unavailable)
    public init() {
        fatalError("\(#function) not implemented")
    }
    
    @available(*, unavailable)
    public convenience init(context: NSManagedObjectContext) {
        fatalError("\(#function) not implemented")
    }
}
