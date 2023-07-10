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
        assert(db.userVersion == 1)
        defer { assert(db.userVersion == 0) }
        
        DDLogVerbose("Downgrade from \(String(describing: db.userVersion)) to 0")
        
        db.userVersion = 0
    }
    
    func downgradeFromV2(_ db: Connection) throws {
        assert(db.userVersion == 2)
        defer { assert(db.userVersion == 1) }
        
        DDLogVerbose("Downgrade from \(String(describing: db.userVersion)) to 1")
        
        let schemaChanger = SchemaChanger(connection: db)
        try schemaChanger.alter(table: "session") { tableDefinition in
            tableDefinition.drop(column: "negotiatedVersion")
        }
        
        db.userVersion = 1
    }
}
