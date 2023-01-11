//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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
import SQLite

public class SQLDHSessionStore: DHSessionStoreProtocol {
    private static let databaseName = "threema-fs.db"
    
    let sessionTable = Table("session")
    
    let myIdentityColumn = Expression<String>("myIdentity")
    let peerIdentityColumn = Expression<String>("peerIdentity")
    let sessionIDColumn = Expression<Data>("sessionId")
    let myCurrentChainKey2DHColumn = Expression<Data?>("myCurrentChainKey_2dh")
    let myCounter2DHColumn = Expression<Int64?>("myCounter_2dh")
    let myCurrentChainKey4DHColumn = Expression<Data?>("myCurrentChainKey_4dh")
    let myCounter4DHColumn = Expression<Int64?>("myCounter_4dh")
    let peerCurrentChainKey2DHColumn = Expression<Data?>("peerCurrentChainKey_2dh")
    let peerCounter2DHColumn = Expression<Int64?>("peerCounter_2dh")
    let peerCurrentChainKey4DHColumn = Expression<Data?>("peerCurrentChainKey_4dh")
    let peerCounter4DHColumn = Expression<Int64?>("peerCounter_4dh")
    let myEphemeralPrivateKeyColumn = Expression<Data?>("myEphemeralPrivateKey")
    let myEphemeralPublicKeyColumn = Expression<Data>("myEphemeralPublicKey")
    
    var db: Connection
    let dbQueue: DispatchQueue
    let keyWrapper: KeyWrapperProtocol
    
    init(path: String, keyWrapper: KeyWrapperProtocol) throws {
        self.db = try Connection(path)
        self.dbQueue = DispatchQueue(label: "SQLDHSessionStore")
        self.keyWrapper = keyWrapper
        
        try db.execute("PRAGMA journal_mode = DELETE;")
        try db.execute("PRAGMA secure_delete = true;")
        try createSessionTable()
        excludeFromBackup(path: path)
    }
    
    convenience init() throws {
        try self
            .init(
                path: (FileUtility.appDataDirectory?.appendingPathComponent(SQLDHSessionStore.databaseName).path)!,
                keyWrapper: KeychainKeyWrapper()
            )
    }
    
    public func exactDHSession(myIdentity: String, peerIdentity: String, sessionID: DHSessionID?) throws -> DHSession? {
        try dbQueue.sync {
            guard let row = try db
                .pluck(filterForSession(myIdentity: myIdentity, peerIdentity: peerIdentity, sessionID: sessionID))
            else {
                return nil
            }
            return try dhSessionFromRow(row: row)
        }
    }
                         
    public func bestDHSession(myIdentity: String, peerIdentity: String) throws -> DHSession? {
        try dbQueue.sync {
            let orderExpression =
                Expression<String>(literal: "iif(myCurrentChainKey_4dh is not null, 1, 0) desc, sessionId asc")
            guard let row = try db
                .pluck(
                    filterForSession(myIdentity: myIdentity, peerIdentity: peerIdentity, sessionID: nil)
                        .order(orderExpression)
                ) else {
                return nil
            }
            return try dhSessionFromRow(row: row)
        }
    }
    
    public func storeDHSession(session: DHSession) throws {
        try dbQueue.sync {
            _ = try db.run(sessionTable.insert(
                or: OnConflict.replace,
                myIdentityColumn <- session.myIdentity,
                peerIdentityColumn <- session.peerIdentity,
                sessionIDColumn <- session.id.value,
                myCurrentChainKey2DHColumn <- try self.keyWrapper.wrap(key: session.myRatchet2DH?.currentChainKey),
                myCounter2DHColumn <- uInt64ToInt64(value: session.myRatchet2DH?.counter),
                myCurrentChainKey4DHColumn <- try self.keyWrapper.wrap(key: session.myRatchet4DH?.currentChainKey),
                myCounter4DHColumn <- uInt64ToInt64(value: session.myRatchet4DH?.counter),
                peerCurrentChainKey2DHColumn <- try self.keyWrapper.wrap(key: session.peerRatchet2DH?.currentChainKey),
                peerCounter2DHColumn <- uInt64ToInt64(value: session.peerRatchet2DH?.counter),
                peerCurrentChainKey4DHColumn <- try self.keyWrapper.wrap(key: session.peerRatchet4DH?.currentChainKey),
                peerCounter4DHColumn <- uInt64ToInt64(value: session.peerRatchet4DH?.counter),
                myEphemeralPrivateKeyColumn <- try self.keyWrapper.wrap(key: session.myEphemeralPrivateKey),
                myEphemeralPublicKeyColumn <- session.myEphemeralPublicKey!
            ))
        }
    }
    
    public func updateDHSessionRatchets(session: DHSession, peer: Bool) throws {
        try dbQueue.sync {
            if peer {
                _ = try db.run(
                    filterForSession(
                        myIdentity: session.myIdentity,
                        peerIdentity: session.peerIdentity,
                        sessionID: session.id
                    )
                    .update(
                        peerCurrentChainKey2DHColumn <- try self.keyWrapper
                            .wrap(key: session.peerRatchet2DH?.currentChainKey),
                        peerCounter2DHColumn <- uInt64ToInt64(value: session.peerRatchet2DH?.counter),
                        peerCurrentChainKey4DHColumn <- try self.keyWrapper
                            .wrap(key: session.peerRatchet4DH?.currentChainKey),
                        peerCounter4DHColumn <- uInt64ToInt64(value: session.peerRatchet4DH?.counter)
                    )
                )
            }
            else {
                _ = try db.run(
                    filterForSession(
                        myIdentity: session.myIdentity,
                        peerIdentity: session.peerIdentity,
                        sessionID: session.id
                    )
                    .update(
                        myCurrentChainKey2DHColumn <- try self.keyWrapper
                            .wrap(key: session.myRatchet2DH?.currentChainKey),
                        myCounter2DHColumn <- uInt64ToInt64(value: session.myRatchet2DH?.counter),
                        myCurrentChainKey4DHColumn <- try self.keyWrapper
                            .wrap(key: session.myRatchet4DH?.currentChainKey),
                        myCounter4DHColumn <- uInt64ToInt64(value: session.myRatchet4DH?.counter)
                    )
                )
            }
        }
    }
    
    public func deleteDHSession(myIdentity: String, peerIdentity: String, sessionID: DHSessionID) throws -> Bool {
        try dbQueue.sync {
            let numDeleted = try db
                .run(
                    filterForSession(myIdentity: myIdentity, peerIdentity: peerIdentity, sessionID: sessionID)
                        .delete()
                )
            return numDeleted > 0
        }
    }
    
    public func deleteAllDHSessions(myIdentity: String, peerIdentity: String) throws -> Int {
        try dbQueue.sync {
            let numDeleted = try db
                .run(filterForSession(myIdentity: myIdentity, peerIdentity: peerIdentity, sessionID: nil).delete())
            return numDeleted
        }
    }
    
    public func deleteAllDHSessionsExcept(
        myIdentity: String,
        peerIdentity: String,
        excludeSessionID: DHSessionID,
        fourDhOnly: Bool
    ) throws -> Int {
        try dbQueue.sync {
            var filter = filterForSessionExclude(
                myIdentity: myIdentity,
                peerIdentity: peerIdentity,
                excludeSessionID: excludeSessionID
            )
            if fourDhOnly {
                filter = filter.filter(myCurrentChainKey4DHColumn != nil)
            }
            let numDeleted = try db.run(filter.delete())
            return numDeleted
        }
    }
    
    // MARK: Private functions
    
    private func createSessionTable() throws {
        try db.run(sessionTable.create(ifNotExists: true) { t in
            t.column(myIdentityColumn)
            t.column(peerIdentityColumn)
            t.column(sessionIDColumn)
            t.column(myCurrentChainKey2DHColumn)
            t.column(myCounter2DHColumn)
            t.column(myCurrentChainKey4DHColumn)
            t.column(myCounter4DHColumn)
            t.column(peerCurrentChainKey2DHColumn)
            t.column(peerCounter2DHColumn)
            t.column(peerCurrentChainKey4DHColumn)
            t.column(peerCounter4DHColumn)
            t.column(myEphemeralPrivateKeyColumn)
            t.column(myEphemeralPublicKeyColumn)
            t.primaryKey(myIdentityColumn, peerIdentityColumn, sessionIDColumn)
        })
    }
    
    private func filterForSession(myIdentity: String, peerIdentity: String, sessionID: DHSessionID?) -> QueryType {
        switch sessionID {
        case let .some(dhSessionID):
            return sessionTable
                .filter(
                    myIdentityColumn == myIdentity && peerIdentityColumn == peerIdentity && sessionIDColumn ==
                        dhSessionID.data()
                )
        case .none:
            return sessionTable.filter(myIdentityColumn == myIdentity && peerIdentityColumn == peerIdentity)
        }
    }
    
    private func filterForSessionExclude(
        myIdentity: String,
        peerIdentity: String,
        excludeSessionID: DHSessionID
    ) -> QueryType {
        sessionTable
            .filter(
                myIdentityColumn == myIdentity && peerIdentityColumn == peerIdentity && sessionIDColumn !=
                    excludeSessionID.data()
            )
    }
    
    private func dhSessionFromRow(row: Row) throws -> DHSession? {
        do {
            return DHSession(
                id: try DHSessionID(value: try row.get(sessionIDColumn)),
                myIdentity: try row.get(myIdentityColumn),
                peerIdentity: try row.get(peerIdentityColumn),
                myEphemeralPrivateKey: try keyWrapper.unwrap(key: row.get(myEphemeralPrivateKeyColumn)),
                myEphemeralPublicKey: try row.get(myEphemeralPublicKeyColumn),
                myRatchet2DH: try ratchetFromRow(
                    row: row,
                    keyColumn: myCurrentChainKey2DHColumn,
                    counterColumn: myCounter2DHColumn
                ),
                myRatchet4DH: try ratchetFromRow(
                    row: row,
                    keyColumn: myCurrentChainKey4DHColumn,
                    counterColumn: myCounter4DHColumn
                ),
                peerRatchet2DH: try ratchetFromRow(
                    row: row,
                    keyColumn: peerCurrentChainKey2DHColumn,
                    counterColumn: peerCounter2DHColumn
                ),
                peerRatchet4DH: try ratchetFromRow(
                    row: row,
                    keyColumn: peerCurrentChainKey4DHColumn,
                    counterColumn: peerCounter4DHColumn
                )
            )
        }
        catch KeyWrappingError.decryptionFailed {
            // This is irrecoverable, and we need to delete the session
            try db
                .run(
                    filterForSession(
                        myIdentity: row.get(myIdentityColumn),
                        peerIdentity: row.get(peerIdentityColumn),
                        sessionID: DHSessionID(value: row.get(sessionIDColumn))
                    )
                    .delete()
                )
            return nil
        }
    }
    
    private func ratchetFromRow(
        row: Row,
        keyColumn: Expression<Data?>,
        counterColumn: Expression<Int64?>
    ) throws -> KDFRatchet? {
        guard let key = try row.get(keyColumn), let counter = try row.get(counterColumn) else {
            return nil
        }
        return KDFRatchet(counter: UInt64(counter), initialChainKey: try keyWrapper.unwrap(key: key)!)
    }
    
    private func excludeFromBackup(path: String) {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var fileURL = URL(fileURLWithPath: path)
        try? fileURL.setResourceValues(resourceValues)
    }
    
    private func uInt64ToInt64(value: UInt64?) throws -> Int64? {
        guard let value = value else {
            return nil
        }
        guard value <= UInt64(Int64.max) else {
            throw ForwardSecurityError.counterOutOfRange
        }
        return Int64(value)
    }
}
