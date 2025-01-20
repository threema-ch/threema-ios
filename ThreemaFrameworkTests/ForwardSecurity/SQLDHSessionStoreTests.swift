//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

class SQLDHSessionStoreTests: XCTestCase {
    /// Number of runs for tests that involve random data
    private static let numRandomRuns = 20
    
    private static let aliceIdentity = "AAAAAAAA"
    private static let bobIdentity = "BBBBBBBB"
    private static let carolIdentity = "CCCCCCCC"
    private static let danIdentity = "DDDDDDDD"
    
    private var storePath: String?
    private var store: SQLDHSessionStore!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        continueAfterFailure = false
        storePath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db").path
        store = try SQLDHSessionStore(path: storePath!, keyWrapper: DummyKeyWrapper())
    }
    
    override func tearDownWithError() throws {
        store = nil
        try FileManager.default.removeItem(atPath: storePath!)
    }
    
    func testStoreRetrieveDHSession() throws {
        let mySession = makeRandomDHSession(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            fourDh: false
        )
        
        try store!.storeDHSession(session: mySession)
        
        // Retrieve session again from DB and compare
        let retrievedSession = try store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        )
        XCTAssertEqual(retrievedSession!, mySession)
        
        // Turn ratchet, store session again (should overwrite) and check
        mySession.myRatchet2DH!.turn()
        try store!.storeDHSession(session: mySession)
        
        let retrievedSession2 = try store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        )
        XCTAssertEqual(retrievedSession2!, mySession)
    }
    
    func testUpdateDHSessionRatchets() throws {
        let mySession = makeRandomDHSession(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            fourDh: true
        )
        
        try store!.storeDHSession(session: mySession)
        
        mySession.myRatchet4DH!.turn()
        try store!.updateDHSessionRatchets(session: mySession, peer: false)
        
        // Retrieve session again from DB and compare
        let retrievedSession = try store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        )
        XCTAssertEqual(retrievedSession!, mySession)
        
        // Do the same for the peer ratchet
        
        mySession.peerRatchet4DH!.turn()
        try store!.updateDHSessionRatchets(session: mySession, peer: true)
        
        let retrievedSession2 = try store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        )
        XCTAssertEqual(retrievedSession2!, mySession)
    }
    
    func testVerifyCannotResetCountersDHSessionRatchets() throws {
        let mySession = makeRandomDHSession(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            fourDh: true
        )
        
        try store!.storeDHSession(session: mySession)
        
        let secondSession = copy(session: mySession)
        
        for _ in 0..<10 {
            mySession.myRatchet4DH!.turn()
        }
        
        try store!.updateDHSessionRatchets(session: mySession, peer: false)
        
        try store!.updateDHSessionRatchets(session: secondSession, peer: false)
        
        // Retrieve session again from DB and compare
        let retrievedSession = try store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        )
        XCTAssertEqual(retrievedSession!, mySession)
        
        XCTAssertEqual(mySession.myRatchet4DH, retrievedSession?.myRatchet4DH)
        XCTAssertNotEqual(secondSession.myRatchet4DH, retrievedSession?.myRatchet4DH)
        
        // Do the same for the peer ratchet
        
        for _ in 0..<10 {
            mySession.peerRatchet4DH!.turn()
        }
        try store!.updateDHSessionRatchets(session: mySession, peer: true)
        
        try store!.updateDHSessionRatchets(session: secondSession, peer: true)
        
        let retrievedSession2 = try store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        )
        XCTAssertEqual(retrievedSession2!, mySession)
        
        XCTAssertEqual(mySession.peerRatchet4DH, retrievedSession2?.peerRatchet4DH)
        XCTAssertNotEqual(secondSession.peerRatchet4DH, retrievedSession2?.peerRatchet4DH)
    }
    
    func testUpdateDHSessionRatchetsButNotVersions() throws {
        let mySession = makeRandomDHSession(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            fourDh: true
        )
        
        try store!.storeDHSession(session: mySession)
                
        mySession.myRatchet4DH!.turn()

        let expectedCurrent4DHVersions = mySession.current4DHVersions
        
        // Upgrade version, but this should not be persisted if only ratchets are persisted
        let processedVersions = ProcessedVersions(
            offeredVersion: .v12,
            appliedVersion: .v12,
            pending4DHVersion: DHVersions(local: .v12, remote: .v12)
        )
        let updatesVersionsSnapshot = mySession.commitVersion(processedVersions: processedVersions)
        XCTAssertNotNil(updatesVersionsSnapshot)
        
        try store!.updateDHSessionRatchets(session: mySession, peer: false)
        
        // Retrieve session again from DB and compare
        let retrievedSession = try XCTUnwrap(store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        ))
        XCTAssertEqual(retrievedSession.id, mySession.id)
        XCTAssertEqual(retrievedSession.myRatchet2DH, mySession.myRatchet2DH)
        XCTAssertEqual(retrievedSession.myRatchet4DH, mySession.myRatchet4DH)
        XCTAssertEqual(retrievedSession.peerRatchet2DH, mySession.peerRatchet2DH)
        XCTAssertEqual(retrievedSession.peerRatchet4DH, mySession.peerRatchet4DH)
        XCTAssertEqual(retrievedSession.current4DHVersions, expectedCurrent4DHVersions)
        XCTAssertNotEqual(retrievedSession.current4DHVersions, mySession.current4DHVersions)

        // Do the same for the peer ratchet
        
        mySession.peerRatchet4DH!.turn()
        try store!.updateDHSessionRatchets(session: mySession, peer: true)
        
        let retrievedSession2 = try XCTUnwrap(store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        ))
        XCTAssertEqual(retrievedSession2.id, mySession.id)
        XCTAssertEqual(retrievedSession2.myRatchet2DH, mySession.myRatchet2DH)
        XCTAssertEqual(retrievedSession2.myRatchet4DH, mySession.myRatchet4DH)
        XCTAssertEqual(retrievedSession2.peerRatchet2DH, mySession.peerRatchet2DH)
        XCTAssertEqual(retrievedSession2.peerRatchet4DH, mySession.peerRatchet4DH)
        XCTAssertEqual(retrievedSession2.current4DHVersions, expectedCurrent4DHVersions)
        XCTAssertNotEqual(retrievedSession2.current4DHVersions, mySession.current4DHVersions)
    }
    
    private func copy(session: DHSession) -> DHSession {
        let myRatchet2DH: KDFRatchet?
        let myRatchet4DH: KDFRatchet?
        let peerRatchet2DH: KDFRatchet?
        let peerRatchet4DH: KDFRatchet?
        
        if let ratchet = session.myRatchet2DH {
            myRatchet2DH = KDFRatchet(counter: ratchet.counter, initialChainKey: ratchet.currentChainKey)
        }
        else {
            myRatchet2DH = nil
        }
        if let ratchet = session.myRatchet4DH {
            myRatchet4DH = KDFRatchet(counter: ratchet.counter, initialChainKey: ratchet.currentChainKey)
        }
        else {
            myRatchet4DH = nil
        }
        if let ratchet = session.peerRatchet2DH {
            peerRatchet2DH = KDFRatchet(counter: ratchet.counter, initialChainKey: ratchet.currentChainKey)
        }
        else {
            peerRatchet2DH = nil
        }
        if let ratchet = session.peerRatchet4DH {
            peerRatchet4DH = KDFRatchet(counter: ratchet.counter, initialChainKey: ratchet.currentChainKey)
        }
        else {
            peerRatchet4DH = nil
        }

        return try! DHSession(
            id: session.id,
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            myEphemeralPrivateKey: session.myEphemeralPrivateKey,
            myEphemeralPublicKey: session.myEphemeralPublicKey,
            myRatchet2DH: myRatchet2DH,
            myRatchet4DH: myRatchet4DH,
            peerRatchet2DH: peerRatchet2DH,
            peerRatchet4DH: peerRatchet4DH,
            current4DHVersions: DHVersions(local: .v11, remote: .v11),
            newSessionCommitted: session.newSessionCommitted,
            lastMessageSent: session.lastMessageSent
        )
    }
    
    func testUpdateDHSessionCommitAndLastMessageSentDate() throws {
        let mySession = makeRandomDHSession(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            fourDh: false
        )
        
        try store!.storeDHSession(session: mySession)
        
        // New session should not be committed and no FS message sent
        XCTAssertFalse(mySession.newSessionCommitted)
        XCTAssertNil(mySession.lastMessageSent)

        mySession.newSessionCommitted = true
        mySession.lastMessageSent = .now
        
        try store!.updateNewSessionCommitLastMessageSentDateAndVersions(session: mySession)
        
        // Retrieve session again from DB and compare
        let retrievedSession = try store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        )
        XCTAssertEqual(retrievedSession!, mySession)
    }
    
    func testUpdateDHSessionLastMessageSentDateAndVersions() throws {
        let mySession = makeRandomDHSession(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            fourDh: true
        )
        
        try store!.storeDHSession(session: mySession)

        mySession.lastMessageSent = .now
        
        // Upgrade versions
        let processedVersions = ProcessedVersions(
            offeredVersion: .v12,
            appliedVersion: .v12,
            pending4DHVersion: DHVersions(local: .v12, remote: .v12)
        )
        let updatesVersionsSnapshot = mySession.commitVersion(processedVersions: processedVersions)
        XCTAssertNotNil(updatesVersionsSnapshot)
        
        try store!.updateNewSessionCommitLastMessageSentDateAndVersions(session: mySession)
        
        // Retrieve session again from DB and compare
        let retrievedSession = try store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        )
        XCTAssertEqual(retrievedSession!, mySession)
    }
    
    func testUpdateDHSessionDoNotAllowVersionsDowngrade() throws {
        let mySession = makeRandomDHSession(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            fourDh: true
        )
        
        try store!.storeDHSession(session: mySession)
        
        // Add some seconds such that we're for sure more than a second apart form the initial date set
        mySession.lastMessageSent = Date(timeIntervalSinceNow: 2)
        
        let expectedCurrent4DHVersions = mySession.current4DHVersions
        
        // Downgrade versions, which should not be persisted
        let processedVersions = ProcessedVersions(
            offeredVersion: .v10,
            appliedVersion: .v10,
            pending4DHVersion: DHVersions(local: .v10, remote: .v10)
        )
        let updatesVersionsSnapshot = mySession.commitVersion(processedVersions: processedVersions)
        XCTAssertNotNil(updatesVersionsSnapshot)
        
        try store!.updateNewSessionCommitLastMessageSentDateAndVersions(session: mySession)
        
        // Retrieve session again from DB and compare
        let retrievedSession = try XCTUnwrap(store!.exactDHSession(
            myIdentity: mySession.myIdentity,
            peerIdentity: mySession.peerIdentity,
            sessionID: mySession.id
        ))

        XCTAssertEqual(retrievedSession.id, mySession.id)
        let actualLastMessageSent = try XCTUnwrap(retrievedSession.lastMessageSent)
        let expectedLastMessageSent = try XCTUnwrap(mySession.lastMessageSent)
        // As the stored date loses some precision we only compare it down to the second
        XCTAssertTrue(actualLastMessageSent.distance(to: expectedLastMessageSent) < 1)
        
        XCTAssertEqual(retrievedSession.current4DHVersions, expectedCurrent4DHVersions)
    }
    
    func testBestDHSession4DH() throws {
        for _ in 1...SQLDHSessionStoreTests.numRandomRuns {
            // Make two different sessions between the same participants
            let mySession1 = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity,
                fourDh: true
            )
            let mySession2 = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity,
                fourDh: true
            )
            
            // Downgrade mySession2 to 2DH
            mySession2.myRatchet4DH = nil
            mySession2.peerRatchet4DH = nil
            
            try store!.storeDHSession(session: mySession1)
            try store!.storeDHSession(session: mySession2)
            
            // Retrieve best session from DB and check that it is really the best one
            let retrievedSession = try store!.bestDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity
            )
            
            // As mySession1 is in 4DH, it should be the best session
            XCTAssertEqual(retrievedSession!, mySession1)
            
            // Delete the two sessions, as we'll make new ones in the next iteration
            let numDeleted = try store!.deleteAllDHSessions(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity
            )
            XCTAssertEqual(numDeleted, 2)
        }
    }
    
    func testBestDHSessionLowestID() throws {
        for _ in 1...SQLDHSessionStoreTests.numRandomRuns {
            // Make two different sessions between the same participants
            let mySession1 = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity,
                fourDh: true
            )
            let mySession2 = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity,
                fourDh: true
            )
            
            try store!.storeDHSession(session: mySession1)
            try store!.storeDHSession(session: mySession2)
            
            // Retrieve best session from DB and check that it is really the best one
            let retrievedSession = try store!.bestDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity
            )
            
            // As both sessions are in 4DH, the best session should be the one with the lower ID
            if mySession1.id < mySession2.id {
                XCTAssertEqual(retrievedSession!, mySession1)
            }
            else {
                XCTAssertEqual(retrievedSession!, mySession2)
            }
            
            // Delete the two sessions, as we'll make new ones in the next iteration
            let numDeleted = try store!.deleteAllDHSessions(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity
            )
            XCTAssertEqual(numDeleted, 2)
        }
    }
    
    func testDeleteAllDHSessionsExcept() throws {
        // Make five different 4DH sessions between the same participants
        var sessions: [DHSession] = []
        for _ in 1...5 {
            let session = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity,
                fourDh: true
            )
            sessions.append(session)
            try store!.storeDHSession(session: session)
        }
        
        // Make one more 2DH session
        let session2Dh = makeRandomDHSession(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            fourDh: false
        )
        try store!.storeDHSession(session: session2Dh)
        
        // Delete all 4DH sessions except for the first
        let numDeleted = try store!.deleteAllDHSessionsExcept(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            excludeSessionID: sessions[0].id,
            fourDhOnly: true
        )
        XCTAssertEqual(numDeleted, 4)
        
        // Delete again, this time without fourDhOnly, and ensure the 2DH session is deleted
        let numDeleted2 = try store!.deleteAllDHSessionsExcept(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity,
            excludeSessionID: sessions[0].id,
            fourDhOnly: false
        )
        XCTAssertEqual(numDeleted2, 1)
        
        // Check that the first session is still in the database
        XCTAssertEqual(
            try store!
                .exactDHSession(
                    myIdentity: sessions[0].myIdentity,
                    peerIdentity: sessions[0].peerIdentity,
                    sessionID: sessions[0].id
                ),
            sessions[0]
        )
        
        // Check that the other sessions are not in the database anymore
        for i in 1..<5 {
            XCTAssertNil(try store!.exactDHSession(
                myIdentity: sessions[i].myIdentity,
                peerIdentity: sessions[i].peerIdentity,
                sessionID: sessions[i].id
            ))
        }
        
        XCTAssertNil(try store!.exactDHSession(
            myIdentity: session2Dh.myIdentity,
            peerIdentity: session2Dh.peerIdentity,
            sessionID: session2Dh.id
        ))
    }
    
    func testExcludeFromBackup() throws {
        XCTAssertTrue(FileManager.default.fileExists(atPath: storePath!))
        let fileURL = URL(fileURLWithPath: storePath!)
        let resourceValues = try fileURL.resourceValues(forKeys: [URLResourceKey.isExcludedFromBackupKey])
        XCTAssertTrue(resourceValues.isExcludedFromBackup!)
    }
    
    func testHasNoInvalidDHSessions() throws {
        for _ in 1...5 {
            let session = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity,
                fourDh: true
            )
            try store.storeDHSession(session: session)
        }
        
        for _ in 1...2 {
            let session = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.carolIdentity,
                fourDh: true
            )
            try store.storeDHSession(session: session)
        }
        
        // Validate
        
        XCTAssertFalse(try store.hasInvalidDHSessions(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity
        ))
        XCTAssertFalse(try store.hasInvalidDHSessions(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.carolIdentity
        ))
        // Test ID with no session at all
        XCTAssertFalse(try store.hasInvalidDHSessions(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.danIdentity
        ))
    }
    
    func testHasOneInvalidDHSessionTooLow() throws {
        // Two Bob sessions: One too low.
        
        try {
            let session = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity,
                fourDh: true
            )
            try store.storeDHSession(session: session)
        }()
        
        try {
            let session = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity,
                fourDh: true
            )
            
            let processedVersions = ProcessedVersions(
                offeredVersion: .UNRECOGNIZED(2),
                appliedVersion: .UNRECOGNIZED(2),
                pending4DHVersion: DHVersions(local: .UNRECOGNIZED(2), remote: .UNRECOGNIZED(2))
            )
            let updatesVersionsSnapshot = session.commitVersion(processedVersions: processedVersions)
            XCTAssertNotNil(updatesVersionsSnapshot)
            
            try store.storeDHSession(session: session)
        }()
        
        // One valid Carol session
        
        try {
            let session = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.carolIdentity,
                fourDh: true
            )
            try store.storeDHSession(session: session)
        }()
        
        // Validate
        
        XCTAssertTrue(try store.hasInvalidDHSessions(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity
        ))
        XCTAssertFalse(try store.hasInvalidDHSessions(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.carolIdentity
        ))
        // Test ID with no session at all
        XCTAssertFalse(try store.hasInvalidDHSessions(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.danIdentity
        ))
    }
    
    func testHasOneInvalidDHSessionTooHigh() throws {
        ThreemaEnvironment.fsVersion = CspE2eFs_VersionRange.with {
            $0.min = UInt32(CspE2eFs_Version.v10.rawValue)
            $0.max = UInt32(CspE2eFs_Version.v11.rawValue)
        }
        
        // One invalid Bob session. Too high.
        
        try {
            let session = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.bobIdentity,
                fourDh: true
            )
            
            let processedVersions = ProcessedVersions(
                offeredVersion: .v11,
                appliedVersion: .v11,
                pending4DHVersion: DHVersions(local: .v12, remote: .v12)
            )
            let updatesVersionsSnapshot = session.commitVersion(processedVersions: processedVersions)
            XCTAssertNotNil(updatesVersionsSnapshot)
            
            try store.storeDHSession(session: session)
        }()
        
        // One valid Carol session
        
        try {
            let session = makeRandomDHSession(
                myIdentity: SQLDHSessionStoreTests.aliceIdentity,
                peerIdentity: SQLDHSessionStoreTests.carolIdentity,
                fourDh: true
            )
            try store.storeDHSession(session: session)
        }()
        
        // Validate
        
        XCTAssertTrue(try store.hasInvalidDHSessions(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.bobIdentity
        ))
        XCTAssertFalse(try store.hasInvalidDHSessions(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.carolIdentity
        ))
        // Test ID with no session at all
        XCTAssertFalse(try store.hasInvalidDHSessions(
            myIdentity: SQLDHSessionStoreTests.aliceIdentity,
            peerIdentity: SQLDHSessionStoreTests.danIdentity
        ))
    }
    
    // MARK: - Private helper
    
    private func makeRandomDHSession(myIdentity: String, peerIdentity: String, fourDh: Bool) -> DHSession {
        if fourDh {
            makeRandomDHSession(myIdentity: myIdentity, peerIdentity: peerIdentity, state: .RL44)
        }
        else {
            makeRandomDHSession(myIdentity: myIdentity, peerIdentity: peerIdentity, state: .L20)
        }
    }

    private func makeRandomDHSession(myIdentity: String, peerIdentity: String, state: DHSession.State) -> DHSession {
        let myEphemeralPrivateKey = randomKey()
        let myEphemeralPublicKey = randomKey()
        let myRatchet2DH: KDFRatchet?
        let myRatchet4DH: KDFRatchet?
        let peerRatchet2DH: KDFRatchet?
        let peerRatchet4DH: KDFRatchet?
        let newSessionCommitted: Bool
        let lastMessageSent: Date?
        
        switch state {
        case .L20:
            myRatchet2DH = KDFRatchet(counter: 1, initialChainKey: randomKey())
            myRatchet4DH = nil
            peerRatchet2DH = nil
            peerRatchet4DH = nil
            newSessionCommitted = false
            lastMessageSent = nil
            
        case .RL44:
            myRatchet2DH = nil
            myRatchet4DH = KDFRatchet(counter: 1, initialChainKey: randomKey())
            peerRatchet2DH = nil
            peerRatchet4DH = KDFRatchet(counter: 1, initialChainKey: randomKey())
            newSessionCommitted = true
            lastMessageSent = .now

        case .R20:
            myRatchet2DH = nil
            myRatchet4DH = nil
            peerRatchet2DH = KDFRatchet(counter: 1, initialChainKey: randomKey())
            peerRatchet4DH = nil
            newSessionCommitted = true
            lastMessageSent = .now

        case .R24:
            myRatchet2DH = nil
            myRatchet4DH = KDFRatchet(counter: 1, initialChainKey: randomKey())
            peerRatchet2DH = KDFRatchet(counter: 1, initialChainKey: randomKey())
            peerRatchet4DH = KDFRatchet(counter: 1, initialChainKey: randomKey())
            newSessionCommitted = true
            lastMessageSent = .now
        }
        
        return try! DHSession(
            id: DHSessionID(),
            myIdentity: myIdentity,
            peerIdentity: peerIdentity,
            myEphemeralPrivateKey: myEphemeralPrivateKey,
            myEphemeralPublicKey: myEphemeralPublicKey,
            myRatchet2DH: myRatchet2DH,
            myRatchet4DH: myRatchet4DH,
            peerRatchet2DH: peerRatchet2DH,
            peerRatchet4DH: peerRatchet4DH,
            current4DHVersions: DHVersions(local: .v11, remote: .v11),
            newSessionCommitted: newSessionCommitted,
            lastMessageSent: lastMessageSent
        )
    }
    
    private func randomKey() -> Data {
        BytesUtility.generateRandomBytes(length: Int(kNaClCryptoSymmKeySize))!
    }
}

class DummyKeyWrapper: KeyWrapperProtocol {
    func wrap(key: Data?) throws -> Data? {
        key
    }

    func unwrap(key: Data?) throws -> Data? {
        key
    }
}
