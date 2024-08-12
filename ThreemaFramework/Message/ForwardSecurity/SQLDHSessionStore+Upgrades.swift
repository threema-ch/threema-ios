//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import SQLite
import ThreemaProtocols

extension SQLDHSessionStore {
    static func upgradeToV1(_ db: Connection) {
        DDLogDebug("[ForwardSecurity] \(#function) \(String(describing: db.userVersion))")
        
        assert(db.userVersion == 0 || db.userVersion == nil)
        
        defer { assert(db.userVersion == 1) }
        
        DDLogVerbose("[ForwardSecurity] Upgrade from \(String(describing: db.userVersion)) to 1")
        
        db.userVersion = 1
        
        DDLogDebug("[ForwardSecurity] \(#function) \(String(describing: db.userVersion))")
    }
    
    func upgradeToV2(_ db: Connection) throws {
        DDLogDebug("[ForwardSecurity] \(#function) \(String(describing: db.userVersion))")
        
        assert(db.userVersion == 1)
        
        defer { assert(db.userVersion == 2) }
        
        DDLogVerbose("[ForwardSecurity] Upgrade from \(String(describing: db.userVersion)) to 2")
        
        do {
            try db.run(sessionTable.addColumn(myCurrentVersion4DHColumn, defaultValue: CspE2eFs_Version.v10.rawValue))
        }
        catch {
            if case .error(
                message: "duplicate column name: negotiatedVersion",
                code: 1,
                statement: nil
            ) = error as? SQLite.Result {
                DDLogNotice("Ignore error \(error)")
            }
            else {
                throw error
            }
        }
        
        db.userVersion = 2
        
        DDLogDebug("[ForwardSecurity] \(#function) \(String(describing: db.userVersion))")
    }
    
    func upgradeToV3(_ db: Connection) throws {
        DDLogDebug("[ForwardSecurity] \(#function) \(String(describing: db.userVersion))")
        
        assert(db.userVersion == 2)
        
        defer { assert(db.userVersion == 3) }
        
        DDLogVerbose("[ForwardSecurity] Upgrade from \(String(describing: db.userVersion)) to 2")
        
        // This is only required if someone updated to a build with a broken migration to v2.
        // In all other cases adding the column will fail and we will ignore the error
        if try db.scalar(sessionTable.count) == 0 {
            do {
                try db.run(
                    sessionTable.addColumn(myCurrentVersion4DHColumn, defaultValue: CspE2eFs_Version.v10.rawValue)
                )
            }
            catch {
                if case .error(
                    message: "duplicate column name: negotiatedVersion",
                    code: 1,
                    statement: nil
                ) = error as? SQLite.Result {
                    DDLogNotice("Ignore error \(error)")
                }
                else {
                    throw error
                }
            }
        }
        
        db.userVersion = 3
        
        DDLogDebug("[ForwardSecurity] \(#function) \(String(describing: db.userVersion))")
    }
    
    func upgradeToV4(_ db: Connection) throws {
        DDLogDebug("[ForwardSecurity] \(#function) \(String(describing: db.userVersion))")
        
        assert(db.userVersion == 3)
        
        defer { assert(db.userVersion == 4) }
        
        DDLogVerbose("[ForwardSecurity] Upgrade from \(String(describing: db.userVersion)) to 4")
        
        // The implementation for Android checks that the column doesn't already exist.
        // We assume that we can execute the upgrade exactly once.
        
        // Create remote 4DH version column with default value 0x0100 (Version 1.0)
        do {
            try db.run(sessionTable.addColumn(peerCurrentVersion4DHColumn, defaultValue: CspE2eFs_Version.v10.rawValue))
        }
        catch {
            if case .error(
                message: "duplicate column name: peerCurrentVersion_4dh",
                code: 1,
                statement: nil
            ) = error as? SQLite.Result {
                DDLogNotice("[ForwardSecurity] Ignore error: \(error)")
            }
            else {
                throw error
            }
        }
        
        db.userVersion = 4
        
        DDLogDebug("[ForwardSecurity] \(#function) \(String(describing: db.userVersion))")
    }
    
    func upgradeToV5(_ db: Connection) throws {
        DDLogDebug("[ForwardSecurity] \(#function) \(String(describing: db.userVersion))")
        
        assert(db.userVersion == 4)
        
        defer { assert(db.userVersion == 5) }
        
        DDLogVerbose("[ForwardSecurity] Upgrade from \(String(describing: db.userVersion)) to 5")
        
        // We assume that we can execute the upgrade exactly once.
        
        do {
            // Create new session committed column with default value `true` as we assume all existing sessions already
            // had an init sent
            try db.run(sessionTable.addColumn(newSessionCommitted, defaultValue: true))
            
            // Create last message sent column with default value `nil` as we don't know when the last FS message was
            // sent
            try db.run(sessionTable.addColumn(lastMessageSent))
        }
        catch SQLite.Result.error(
            message: "duplicate column name: newSessionCommitted",
            code: 1,
            statement: nil
        ) {
            DDLogNotice("[ForwardSecurity] Ignore error duplicate column name: newSessionCommitted")
        }
        catch SQLite.Result.error(
            message: "duplicate column name: lastMessageSent",
            code: 1,
            statement: nil
        ) {
            DDLogNotice("[ForwardSecurity] Ignore error duplicate column name: lastMessageSent")
        }
        
        db.userVersion = 5
        
        DDLogDebug("[ForwardSecurity] \(#function) \(String(describing: db.userVersion))")
    }
}
