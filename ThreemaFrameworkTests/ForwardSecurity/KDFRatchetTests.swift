import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class KDFRatchetTests: XCTestCase {
    let initialChainKey = Data(
        BytesUtility
            .toBytes(hexString: "421e73cf324785dee4c4830f2efbb8cd4b258ed8520a608a6ce340aaa7400024")!
    )
    let expectedEncryptionKey1 = Data(
        BytesUtility
            .toBytes(hexString: "60d3de2d849fa8b3d9799e8e50b09a7ef1d4e1e855c99fdb711bfe29466cdad3")!
    )
    let expectedEncryptionKey100 = Data(
        BytesUtility
            .toBytes(hexString: "d2acf6e1c7262eb360ad92b6a74e0f9ad6ee129278742fc2462ae72916eaa334")!
    )
    let tooManyTurns = 1_000_000
    
    override func setUp() {
        continueAfterFailure = false
    }
    
    func testTurnOnce() {
        let ratchet = KDFRatchet(counter: 0, initialChainKey: initialChainKey)
        ratchet.turn()
        
        XCTAssertEqual(ratchet.counter, 1)
        XCTAssertEqual(ratchet.currentEncryptionKey, expectedEncryptionKey1)
    }
    
    func testTurnMany() throws {
        let ratchet = KDFRatchet(counter: 0, initialChainKey: initialChainKey)
        let numTurns = try ratchet.turnUntil(targetCounterValue: 100)
        
        XCTAssertEqual(numTurns, 100)
        XCTAssertEqual(ratchet.counter, 100)
        XCTAssertEqual(ratchet.currentEncryptionKey, expectedEncryptionKey100)
    }
    
    func testTurnTooMany() {
        let ratchet = KDFRatchet(counter: 0, initialChainKey: initialChainKey)
        XCTAssertThrowsError(try ratchet.turnUntil(targetCounterValue: UInt64(tooManyTurns)))
    }
}
