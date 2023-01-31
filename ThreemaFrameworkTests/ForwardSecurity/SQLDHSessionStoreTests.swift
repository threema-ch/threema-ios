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

import XCTest
@testable import ThreemaFramework

class SQLDHSessionStoreTests: XCTestCase {
    /// Number of runs for tests that involve random data
    private static let numRandomRuns = 20
    
    private static let aliceIdentity = "AAAAAAAA"
    private static let bobIdentity = "BBBBBBBB"
    
    private var storePath: String?
    private var store: SQLDHSessionStore?
    
    override func setUpWithError() throws {
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
            fourDh: true
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
    
    private func makeRandomDHSession(myIdentity: String, peerIdentity: String, fourDh: Bool) -> DHSession {
        let myEphemeralPrivateKey = randomKey()
        let myEphemeralPublicKey = randomKey()
        let myRatchet2DH = KDFRatchet(counter: 1, initialChainKey: randomKey())
        let myRatchet4DH = fourDh ? KDFRatchet(counter: 1, initialChainKey: randomKey()) : nil
        let peerRatchet2DH = KDFRatchet(counter: 1, initialChainKey: randomKey())
        let peerRatchet4DH = fourDh ? KDFRatchet(counter: 1, initialChainKey: randomKey()) : nil
        return DHSession(
            id: DHSessionID(),
            myIdentity: myIdentity,
            peerIdentity: peerIdentity,
            myEphemeralPrivateKey: myEphemeralPrivateKey,
            myEphemeralPublicKey: myEphemeralPublicKey,
            myRatchet2DH: myRatchet2DH,
            myRatchet4DH: myRatchet4DH,
            peerRatchet2DH: peerRatchet2DH,
            peerRatchet4DH: peerRatchet4DH
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
