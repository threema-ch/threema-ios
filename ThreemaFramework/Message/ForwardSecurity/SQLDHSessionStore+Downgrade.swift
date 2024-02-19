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

extension SQLDHSessionStore {
    static func downgradeFromV1(_ db: Connection) {
        DDLogNotice("[SQLDHSessionStoreMigration] \(#function) \(String(describing: db.userVersion))")
        assert(db.userVersion == 1)
        defer { assert(db.userVersion == 0) }
        
        DDLogNotice("Downgrade from \(String(describing: db.userVersion)) to 0")
        
        db.userVersion = 0
        
        DDLogNotice("[SQLDHSessionStoreMigration] \(#function) \(String(describing: db.userVersion))")
    }
    
    func downgradeFromV2(_ db: Connection) throws {
        DDLogNotice("[SQLDHSessionStoreMigration] \(#function) \(String(describing: db.userVersion))")
        
        assert(db.userVersion == 2)
        
        defer { assert(db.userVersion == 1) }
        
        DDLogNotice("Downgrade from \(String(describing: db.userVersion)) to 1")
        
        let schemaChanger = SchemaChanger(connection: db)
        try schemaChanger.alter(table: "session") { tableDefinition in
            tableDefinition.drop(column: "negotiatedVersion")
        }
        
        db.userVersion = 1
        
        DDLogNotice("[SQLDHSessionStoreMigration] \(#function) \(String(describing: db.userVersion))")
    }
    
    func downgradeFromV3(_ db: Connection) throws {
        DDLogNotice("[SQLDHSessionStoreMigration] \(#function) \(String(describing: db.userVersion))")
        
        assert(db.userVersion == 3)
        
        defer { assert(db.userVersion == 2) }
        
        DDLogNotice("Downgrade from \(String(describing: db.userVersion)) to 2")
        
        // Migration to V3 only ensures that V2 was completed successfully
        // It is equivalent to assuming version 2.
        
        db.userVersion = 2
        
        DDLogNotice("[SQLDHSessionStoreMigration] \(#function) \(String(describing: db.userVersion))")
    }
    
    func downgradeFromV4(_ db: Connection) throws {
        DDLogNotice("[SQLDHSessionStoreMigration] \(#function) \(String(describing: db.userVersion))")
        
        assert(db.userVersion == 4)
        
        defer { assert(db.userVersion == 3) }
        
        DDLogNotice("Downgrade from \(String(describing: db.userVersion)) to 3")
        
        let schemaChanger = SchemaChanger(connection: db)
        try schemaChanger.alter(table: "session") { tableDefinition in
            tableDefinition.drop(column: "peerCurrentVersion_4dh")
        }
        
        db.userVersion = 3
        
        DDLogNotice("[SQLDHSessionStoreMigration] \(#function) \(String(describing: db.userVersion))")
    }
    
    func downgradeFromV5(_ db: Connection) throws {
        DDLogNotice("[SQLDHSessionStoreMigration] \(#function) \(String(describing: db.userVersion))")
        
        assert(db.userVersion == 5)
        
        defer { assert(db.userVersion == 4) }
        
        DDLogNotice("Downgrade from \(String(describing: db.userVersion)) to 4")
        
        let schemaChanger = SchemaChanger(connection: db)
        try schemaChanger.alter(table: "session") { tableDefinition in
            tableDefinition.drop(column: "newSessionCommitted")
            tableDefinition.drop(column: "lastMessageSent")
        }
        
        db.userVersion = 4
        
        DDLogNotice("[SQLDHSessionStoreMigration] \(#function) \(String(describing: db.userVersion))")
    }
}
