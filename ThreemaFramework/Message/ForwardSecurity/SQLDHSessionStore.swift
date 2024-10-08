//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

public protocol SQLDHSessionStoreErrorHandler: AnyObject {
    func handleDHSessionIllegalStateError(sessionID: DHSessionID, peerIdentity: String)
}

public class SQLDHSessionStore: DHSessionStoreProtocol {
    private static let databaseName = "threema-fs.db"
    private static let databasePath = (
        FileUtility.shared.appDataDirectory?
            .appendingPathComponent(SQLDHSessionStore.databaseName).path
    )!
    
    public struct SQLDHSessionStoreVersionInfo {
        let dbVersion: Int32
        let maximumSupportedDowngradeVersion: Int32
    }
    
    public enum SQLDHSessionStoreMigrationError: Error {
        case downgradeFromUnsupportedVersion(NSError)
        case unknownError(NSError)
    }
    
    public weak var errorHandler: SQLDHSessionStoreErrorHandler?
    
    let sessionTable = Table("session")
    
    // MARK: Columns
    
    // See `DHSession` for documentation of these columns
    
    let myIdentityColumn = SQLite.Expression<String>("myIdentity")
    let peerIdentityColumn = SQLite.Expression<String>("peerIdentity")
    let sessionIDColumn = SQLite.Expression<Data>("sessionId")
    let myCurrentChainKey2DHColumn = SQLite.Expression<Data?>("myCurrentChainKey_2dh")
    let myCounter2DHColumn = SQLite.Expression<Int64?>("myCounter_2dh")
    let myCurrentChainKey4DHColumn = SQLite.Expression<Data?>("myCurrentChainKey_4dh")
    let myCounter4DHColumn = SQLite.Expression<Int64?>("myCounter_4dh")
    let peerCurrentChainKey2DHColumn = SQLite.Expression<Data?>("peerCurrentChainKey_2dh")
    let peerCounter2DHColumn = SQLite.Expression<Int64?>("peerCounter_2dh")
    let peerCurrentChainKey4DHColumn = SQLite.Expression<Data?>("peerCurrentChainKey_4dh")
    let peerCounter4DHColumn = SQLite.Expression<Int64?>("peerCounter_4dh")
    let myEphemeralPrivateKeyColumn = SQLite.Expression<Data?>("myEphemeralPrivateKey")
    let myEphemeralPublicKeyColumn = SQLite.Expression<Data>("myEphemeralPublicKey")
    // Note: Should be named `myCurrentVersion_4dh` but it's too late now
    let myCurrentVersion4DHColumn = SQLite.Expression<Int?>("negotiatedVersion")
    let peerCurrentVersion4DHColumn = SQLite.Expression<Int?>("peerCurrentVersion_4dh")
    let newSessionCommitted = SQLite.Expression<Bool>("newSessionCommitted")
    let lastMessageSent = SQLite.Expression<Date?>("lastMessageSent")
    
    fileprivate let versionInfo: SQLDHSessionStoreVersionInfo
    
    fileprivate static let defaultVersionInfo = SQLDHSessionStoreVersionInfo(
        dbVersion: 5,
        maximumSupportedDowngradeVersion: 5
    )
    
    var db: Connection
    let dbQueue: DispatchQueue
    let keyWrapper: KeyWrapperProtocol
    
    init(
        path: String,
        keyWrapper: KeyWrapperProtocol,
        versionInfo: SQLDHSessionStoreVersionInfo = defaultVersionInfo
    ) throws {
        self.db = try Connection(path)
        self.dbQueue = DispatchQueue(label: "SQLDHSessionStore")
        self.keyWrapper = keyWrapper
        self.versionInfo = versionInfo
        
        DDLogDebug(
            "[ForwardSecurity] Initialized session store with version \(db.userVersion ?? "unknown")"
        )
        
        // Ensure that we are securely deleting entries (no WAL mode / journal mode 'DELETE' and secure_delete on as
        // stated in the cryptography whitepaper)
        try db.execute("PRAGMA journal_mode = DELETE;")
        try db.execute("PRAGMA secure_delete = true;")
        try createSessionTable()
        
        excludeFromBackup(path: path)
    }
    
    convenience init() throws {
        try self.init(
            path: SQLDHSessionStore.databasePath,
            keyWrapper: KeychainKeyWrapper()
        )
    }
    
    public static func deleteSessionDB() {
        #if !DEBUG
            guard SettingsBundleHelper.safeMode else {
                return
            }
        #endif
        
        guard let pathAsURL = URL(string: SQLDHSessionStore.databasePath) else {
            return
        }
        FileUtility.shared.delete(at: pathAsURL)
    }
    
    func upgradeIfNecessary() throws {
        DDLogNotice(
            "[ForwardSecurity] Start session store migration with version \(String(describing: db.userVersion)) and \(versionInfo.dbVersion)"
        )
        let currentVersion = db.userVersion ?? 0
        if currentVersion != versionInfo.dbVersion {
            do {
                try db.transaction {
                    if currentVersion < versionInfo.dbVersion {
                        try onUpgrade(
                            db: self.db,
                            oldVersion: currentVersion,
                            newVersion: versionInfo.dbVersion
                        )
                    }
                    else if currentVersion > versionInfo.dbVersion {
                        try onDowngrade(
                            db: self.db,
                            oldVersion: currentVersion,
                            newVersion: versionInfo.dbVersion
                        )
                    }
                }
            }
            catch {
                guard !(error is SQLDHSessionStoreMigrationError) else {
                    throw error
                }
                
                throw SQLDHSessionStore.generalError(from: error)
            }
        }
    }
    
    func onUpgrade(db: Connection, oldVersion: Int32, newVersion: Int32) throws {
        DDLogNotice("[ForwardSecurity] Upgrade migration start")
        if oldVersion < 1, newVersion >= 1 {
            DDLogNotice("[ForwardSecurity] Migration upgrade to v1")
            SQLDHSessionStore.upgradeToV1(db)
        }
        
        if oldVersion < 2, newVersion >= 2 {
            DDLogNotice("[ForwardSecurity] Migration upgrade to v2")
            try upgradeToV2(db)
        }
        
        if oldVersion < 3, newVersion >= 3 {
            DDLogNotice("[ForwardSecurity] Migration upgrade to v3")
            try upgradeToV3(db)
        }
        
        if oldVersion < 4, newVersion >= 4 {
            DDLogNotice("[ForwardSecurity] Migration upgrade to v4")
            try upgradeToV4(db)
        }
        
        if oldVersion < 5, newVersion >= 5 {
            DDLogNotice("[ForwardSecurity] Migration upgrade to v5")
            try upgradeToV5(db)
        }
        
        DDLogNotice("[ForwardSecurity] Upgrade migration finished")
    }
    
    func onDowngrade(db: Connection, oldVersion: Int32, newVersion: Int32) throws {
        DDLogNotice("[ForwardSecurity] Downgrade migration start")
        
        guard oldVersion <= versionInfo.maximumSupportedDowngradeVersion else {
            throw SQLDHSessionStore.downgradeError(
                oldVersion: oldVersion,
                newVersion: newVersion,
                versionInfo: versionInfo
            )
        }
        
        if oldVersion > 4, newVersion <= 4 {
            DDLogNotice("[ForwardSecurity] Migration downgrade from v5")
            try downgradeFromV5(db)
        }
        
        if oldVersion > 3, newVersion <= 3 {
            DDLogNotice("[ForwardSecurity] Migration downgrade from v4")
            try downgradeFromV4(db)
        }
        
        if oldVersion > 2, newVersion <= 2 {
            DDLogNotice("[ForwardSecurity] Migration downgrade from v3")
            try downgradeFromV3(db)
        }
        
        if oldVersion > 1, newVersion <= 1 {
            DDLogNotice("[ForwardSecurity] Migration downgrade from v2")
            try downgradeFromV2(db)
        }
        
        if oldVersion > 0, newVersion <= 0 {
            DDLogNotice("[ForwardSecurity] Migration downgrade from v1")
            SQLDHSessionStore.downgradeFromV1(db)
        }
        
        DDLogNotice("[ForwardSecurity] Downgrade migration finished")
    }
    
    public func executeNull() throws {
        DDLogNotice(
            "[ForwardSecurity] Migration start with version \(String(describing: db.userVersion))"
        )
        try dbQueue.sync {
            DDLogNotice(
                "[ForwardSecurity] Migration entered dbQueue with version \(String(describing: db.userVersion))"
            )
            try upgradeIfNecessary()
            DDLogNotice(
                "[ForwardSecurity] Migration exit dbQueue with version \(String(describing: db.userVersion))"
            )
        }
        
        DDLogNotice(
            "[ForwardSecurity] Migration finished with version \(String(describing: db.userVersion))"
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
            let orderExpression = SQLite.Expression<String>(
                literal: "iif(myCurrentChainKey_4dh is not null, 1, 0) desc, sessionId asc"
            )
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
                myCurrentChainKey2DHColumn <- self.keyWrapper.wrap(key: session.myRatchet2DH?.currentChainKey),
                myCounter2DHColumn <- uInt64ToInt64(value: session.myRatchet2DH?.counter),
                myCurrentChainKey4DHColumn <- self.keyWrapper.wrap(key: session.myRatchet4DH?.currentChainKey),
                myCounter4DHColumn <- uInt64ToInt64(value: session.myRatchet4DH?.counter),
                peerCurrentChainKey2DHColumn <- self.keyWrapper.wrap(key: session.peerRatchet2DH?.currentChainKey),
                peerCounter2DHColumn <- uInt64ToInt64(value: session.peerRatchet2DH?.counter),
                peerCurrentChainKey4DHColumn <- self.keyWrapper.wrap(key: session.peerRatchet4DH?.currentChainKey),
                peerCounter4DHColumn <- uInt64ToInt64(value: session.peerRatchet4DH?.counter),
                myEphemeralPrivateKeyColumn <- self.keyWrapper.wrap(key: session.myEphemeralPrivateKey),
                myEphemeralPublicKeyColumn <- session.myEphemeralPublicKey!,
                myCurrentVersion4DHColumn <- (session.current4DHVersions?.local ?? .v10).rawValue,
                peerCurrentVersion4DHColumn <- session.current4DHVersions?.remote.rawValue,
                newSessionCommitted <- session.newSessionCommitted,
                lastMessageSent <- session.lastMessageSent
            ))
            DDLogVerbose("[ForwardSecurity] Stored: \(session.description)")
        }
    }
    
    public func updateDHSessionRatchets(session: DHSession, peer: Bool) throws {
        try dbQueue.sync {
            if peer {
                _ = try db.run(
                    filterForSession(
                        myIdentity: session.myIdentity,
                        peerIdentity: session.peerIdentity,
                        sessionID: session.id,
                        // To avoid accidentally returning the ratchet counters to an earlier state we check
                        // for session with only counters that are lower than what we have in the session we want to
                        // update to.
                        //
                        // We only update the session if the ratchets are further along than what is currently stored in
                        // the DB.
                        //
                        // This resolves an issue where we would go back to a previous session state if we process a
                        // message in the app and before we are able to send the read receipt (which we wait for in
                        // TaskExecutionReceiveMessage) we would close the app disconnect from the server and thus won't
                        // be able to send the read receipt keeping the task alive. (All other tasks will be removed
                        // from the queue.) This then causes the server to send out a push as we haven't acked the
                        // message, which launches the notification extension which then processes the message. If n
                        // additional messages are received before we open the app again, the ratchets are further along
                        // than what we have in the session in the task in the app. Launching the app will then cause
                        // the read receipt to be sent, and the session to be "updated" to the previous state. The next
                        // received message will cause an error message to appear claiming that n messages were lost
                        // since receiving the last message when in fact no messages were lost.
                        peerCounter2DH: uInt64ToInt64(value: session.peerRatchet2DH?.counter),
                        peerCounter4DH: uInt64ToInt64(value: session.peerRatchet4DH?.counter)
                    )
                    .update(
                        peerCurrentChainKey2DHColumn <- self.keyWrapper
                            .wrap(key: session.peerRatchet2DH?.currentChainKey),
                        peerCounter2DHColumn <- uInt64ToInt64(value: session.peerRatchet2DH?.counter),
                        peerCurrentChainKey4DHColumn <- self.keyWrapper
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
                        sessionID: session.id,
                        // To avoid accidentally returning the ratchet counters to an earlier state we check
                        // for session with only counters that are lower than what we have in the session we want to
                        // update to.
                        myCounter2DH: uInt64ToInt64(value: session.myRatchet2DH?.counter),
                        myCounter4DH: uInt64ToInt64(value: session.myRatchet4DH?.counter)
                    )
                    .update(
                        myCurrentChainKey2DHColumn <- self.keyWrapper
                            .wrap(key: session.myRatchet2DH?.currentChainKey),
                        myCounter2DHColumn <- uInt64ToInt64(value: session.myRatchet2DH?.counter),
                        myCurrentChainKey4DHColumn <- self.keyWrapper
                            .wrap(key: session.myRatchet4DH?.currentChainKey),
                        myCounter4DHColumn <- uInt64ToInt64(value: session.myRatchet4DH?.counter)
                    )
                )
            }
        }
        DDLogVerbose("[ForwardSecurity] Updated: \(session.description)")
    }
    
    public func updateNewSessionCommitLastMessageSentDateAndVersions(session: DHSession) throws {
        // Validate that the session is now marked as committed
        if !session.newSessionCommitted {
            DDLogWarn(
                "[ForwardSecurity] Updating last message date in a non-committed session. This should never happen."
            )
            assertionFailure()
        }
        
        try dbQueue.sync {
            _ = try db.run(
                filterForSession(
                    myIdentity: session.myIdentity,
                    peerIdentity: session.peerIdentity,
                    sessionID: session.id
                ).update(
                    newSessionCommitted <- session.newSessionCommitted,
                    lastMessageSent <- session.lastMessageSent
                )
            )
            
            // Only update versions if they didn't change or increased
            _ = try db.run(
                filterForSession(
                    myIdentity: session.myIdentity,
                    peerIdentity: session.peerIdentity,
                    sessionID: session.id,
                    myCurrentVersion4DH: session.current4DHVersions?.local.rawValue,
                    peerCurrentVersion4DH: session.current4DHVersions?.remote.rawValue
                ).update(
                    myCurrentVersion4DHColumn <- (session.current4DHVersions?.local ?? .v10).rawValue,
                    peerCurrentVersion4DHColumn <- session.current4DHVersions?.remote.rawValue
                )
            )
        }
        DDLogVerbose(
            "[ForwardSecurity] Updated new session committed (\(session.newSessionCommitted)) and last message sent (\(String(describing: session.lastMessageSent))) in \(session.description)"
        )
    }
    
    public func deleteDHSession(myIdentity: String, peerIdentity: String, sessionID: DHSessionID) throws -> Bool {
        try dbQueue.sync {
            let numDeleted = try db
                .run(
                    filterForSession(myIdentity: myIdentity, peerIdentity: peerIdentity, sessionID: sessionID)
                        .delete()
                )
            DDLogNotice(
                "[ForwardSecurity] Tried deleting: \(sessionID.description) peer: \(peerIdentity), count deleted: \(numDeleted)"
            )
            return numDeleted > 0
        }
    }
    
    public func deleteAllDHSessions(myIdentity: String, peerIdentity: String) throws -> Int {
        try dbQueue.sync {
            let numDeleted = try db
                .run(filterForSession(myIdentity: myIdentity, peerIdentity: peerIdentity, sessionID: nil).delete())
            DDLogNotice(
                "[ForwardSecurity] Tried deleting all DH Session with peer: \(peerIdentity), count deleted: \(numDeleted)"
            )

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
            
            DDLogDebug(
                "[ForwardSecurity] Tried deleting all DH Session with peer: \(peerIdentity) except: \(excludeSessionID), count deleted: \(numDeleted)"
            )
            
            return numDeleted
        }
    }
    
    public func hasInvalidDHSessions(myIdentity: String, peerIdentity: String) throws -> Bool {
        try dbQueue.sync {
            let numberInvalidDHSessions = try db.scalar(
                filterInvalidSessions(myIdentity: myIdentity, peerIdentity: peerIdentity).count
            )
            
            return numberInvalidDHSessions > 0
        }
    }
    
    // MARK: Private functions
    
    private func createSessionTable() throws {
        /// When creating a new table, we set it to the current user version otherwise we'll try to upgrade to a version
        /// we already use on the next run.
        ///
        /// If the table doesn't exist, an error is thrown https://github.com/stephencelis/SQLite.swift/issues/693
        do {
            if try !(db.scalar(sessionTable.exists)) {
                // This is also reached for clients with no FS support as the store is still initialized when an
                // incoming message is processed
                DDLogDebug("[ForwardSecurity] DB creation: The table exists and has zero rows.")
            }
        }
        catch {
            // Ignore errors
            
            DDLogNotice("[ForwardSecurity] Set DB version because the table does not yet exist: \(error)")
            db.userVersion = versionInfo.dbVersion
        }
        
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
            t.column(myCurrentVersion4DHColumn)
            t.column(peerCurrentVersion4DHColumn)
            t.column(newSessionCommitted, defaultValue: false)
            t.column(lastMessageSent)
            t.primaryKey(myIdentityColumn, peerIdentityColumn, sessionIDColumn)
        })
    }
    
    private func filterForSession(
        myIdentity: String,
        peerIdentity: String,
        sessionID: DHSessionID?,
        myCounter2DH: Int64? = nil,
        myCounter4DH: Int64? = nil,
        peerCounter2DH: Int64? = nil,
        peerCounter4DH: Int64? = nil,
        myCurrentVersion4DH: Int? = nil,
        peerCurrentVersion4DH: Int? = nil
    ) -> QueryType {
        switch sessionID {
        case let .some(dhSessionID):
            var queryType = sessionTable
                .filter(
                    myIdentityColumn == myIdentity && peerIdentityColumn == peerIdentity && sessionIDColumn ==
                        dhSessionID.value
                )
            if let myCounter2DH {
                queryType = queryType.filter(myCounter2DHColumn <= myCounter2DH)
            }
            if let myCounter4DH {
                queryType = queryType.filter(myCounter4DHColumn <= myCounter4DH)
            }
            if let peerCounter2DH {
                queryType = queryType.filter(peerCounter2DHColumn <= peerCounter2DH)
            }
            if let peerCounter4DH {
                queryType = queryType.filter(peerCounter4DHColumn <= peerCounter4DH)
            }
            
            if let myCurrentVersion4DH {
                queryType = queryType.filter(myCurrentVersion4DHColumn <= myCurrentVersion4DH)
            }
            if let peerCurrentVersion4DH {
                queryType = queryType.filter(peerCurrentVersion4DHColumn <= peerCurrentVersion4DH)
            }
            
            return queryType
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
                    excludeSessionID.value
            )
    }
    
    private func filterInvalidSessions(
        myIdentity: String,
        peerIdentity: String
    ) -> SchemaType {
        sessionTable.filter(
            myIdentityColumn == myIdentity && peerIdentityColumn == peerIdentity &&
                // Check if any version is smaller than the min supported version or bigger than the max supported
                (
                    myCurrentVersion4DHColumn < Int(ThreemaEnvironment.fsVersion.min) ||
                        myCurrentVersion4DHColumn > Int(ThreemaEnvironment.fsVersion.max) ||
                        peerCurrentVersion4DHColumn < Int(ThreemaEnvironment.fsVersion.min) ||
                        peerCurrentVersion4DHColumn > Int(ThreemaEnvironment.fsVersion.max)
                )
        )
    }
    
    private func dhSessionFromRow(row: Row) throws -> DHSession? {
        do {
            return try DHSession(
                id: DHSessionID(value: row.get(sessionIDColumn)),
                myIdentity: row.get(myIdentityColumn),
                peerIdentity: row.get(peerIdentityColumn),
                myEphemeralPrivateKey: keyWrapper.unwrap(key: row.get(myEphemeralPrivateKeyColumn)),
                myEphemeralPublicKey: row.get(myEphemeralPublicKeyColumn),
                myRatchet2DH: ratchetFromRow(
                    row: row,
                    keyColumn: myCurrentChainKey2DHColumn,
                    counterColumn: myCounter2DHColumn
                ),
                myRatchet4DH: ratchetFromRow(
                    row: row,
                    keyColumn: myCurrentChainKey4DHColumn,
                    counterColumn: myCounter4DHColumn
                ),
                peerRatchet2DH: ratchetFromRow(
                    row: row,
                    keyColumn: peerCurrentChainKey2DHColumn,
                    counterColumn: peerCounter2DHColumn
                ),
                peerRatchet4DH: ratchetFromRow(
                    row: row,
                    keyColumn: peerCurrentChainKey4DHColumn,
                    counterColumn: peerCounter4DHColumn
                ),
                current4DHVersions: dhVersions(from: row),
                newSessionCommitted: row.get(newSessionCommitted),
                lastMessageSent: row.get(lastMessageSent)
            )
        }
        catch KeyWrappingError.decryptionFailed {
            // This is irrecoverable, and we need to delete the session
            DDLogError("[ForwardSecurity] KeyWrapping error 'decryption failed' in \(#function). Deleting session.")
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
        catch let DHSession.State.StateError.invalidStateError(description) {
            // This is irrecoverable, and we need to delete the session
            DDLogError("[ForwardSecurity] Invalid state error in \(#function). Deleting session. \(description)")
            try errorHandler?.handleDHSessionIllegalStateError(
                sessionID: DHSessionID(value: row.get(sessionIDColumn)),
                peerIdentity: row.get(peerIdentityColumn)
            )

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
        keyColumn: SQLite.Expression<Data?>,
        counterColumn: SQLite.Expression<Int64?>
    ) throws -> KDFRatchet? {
        guard let key = try row.get(keyColumn), let counter = try row.get(counterColumn) else {
            return nil
        }
        return try KDFRatchet(counter: UInt64(counter), initialChainKey: keyWrapper.unwrap(key: key)!)
    }
    
    private func dhVersions(
        from row: Row
    ) throws -> DHVersions? {
        guard let rawMyCurrentVersion4DH = try row.get(myCurrentVersion4DHColumn),
              let local = CspE2eFs_Version(rawValue: rawMyCurrentVersion4DH),
              let rawPeerCurrentVersion4DH = try row.get(peerCurrentVersion4DHColumn),
              let remote = CspE2eFs_Version(rawValue: rawPeerCurrentVersion4DH) else {
            return nil
        }
        
        return DHVersions(local: local, remote: remote)
    }
    
    private func excludeFromBackup(path: String) {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var fileURL = URL(fileURLWithPath: path)
        try? fileURL.setResourceValues(resourceValues)
    }
    
    private func uInt64ToInt64(value: UInt64?) throws -> Int64? {
        guard let value else {
            return nil
        }
        guard value <= UInt64(Int64.max) else {
            throw ForwardSecurityError.counterOutOfRange
        }
        return Int64(value)
    }
    
    // MARK: - Error Helpers
    
    private static func downgradeError(
        oldVersion: Int32,
        newVersion: Int32,
        versionInfo: SQLDHSessionStoreVersionInfo
    ) -> SQLDHSessionStoreMigrationError {
        let baseString = BundleUtil.localizedString(forKey: "sqldhsessionstore_cannot_downgrade_to")
        let localizedDescription = String.localizedStringWithFormat(
            baseString,
            "SQLDHSessionStore.swift",
            oldVersion,
            versionInfo.maximumSupportedDowngradeVersion
        )

        let dict = [NSLocalizedDescriptionKey: localizedDescription]
        let nsError = NSError(domain: "\(type(of: self))", code: 1, userInfo: dict)
        
        return SQLDHSessionStoreMigrationError.downgradeFromUnsupportedVersion(nsError)
    }
    
    private static func generalError(from error: Error) -> SQLDHSessionStoreMigrationError {
        let baseString = BundleUtil.localizedString(forKey: "sqldhsessionstore_unknownError")
        let localizedDescription = String.localizedStringWithFormat(
            baseString,
            error.localizedDescription
        )
        let dict = [NSLocalizedDescriptionKey: localizedDescription]
        let nsError = NSError(domain: "\(type(of: self))", code: 2, userInfo: dict)
        
        let wrappedError = SQLDHSessionStoreMigrationError.unknownError(nsError)
        
        return wrappedError
    }
}
