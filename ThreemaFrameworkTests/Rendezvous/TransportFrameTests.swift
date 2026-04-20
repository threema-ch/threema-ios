import XCTest
@testable import ThreemaFramework

final class TransportFrameTests: XCTestCase {

    // TODO: (IOS-3922) Reimplement when decoding chunked frames is correctly implemented
    
    func testAddAndRemoveFrame() throws {
        let testData = Data(repeating: 0x12, count: 10)
        
        let chunks = try TransportFrame.chunkedFrame(from: testData, maxChunkSize: 100)
        let actualData = try TransportFrame.data(from: chunks[0])

        XCTAssertEqual(actualData, testData)
    }
    
    func testWrongFrameSize() throws {
        let testData = Data(repeating: 0xAB, count: 100)

        let chunks = try TransportFrame.chunkedFrame(from: testData, maxChunkSize: 104)
        var frame = chunks[0]
        frame[0] = 200
        
        XCTAssertThrowsError(try TransportFrame.data(from: frame))
    }
    
    func testFrameIs4BytesLonger() throws {
        let numberOfBytes = 500
        
        let testData = Data(repeating: 0xF0, count: numberOfBytes)
        let chunks = try TransportFrame.chunkedFrame(from: testData, maxChunkSize: numberOfBytes + 4)

        XCTAssertEqual(chunks[0].count, numberOfBytes + 4)
    }
    
    // MARK: - Chunks
    
    func testNumberOfChunks() throws {
        let numberOfBytes = 10
        let maxChunkSize = 3
        let expectedNumberOfChunks = 5 // Round up (10 + 4) / 3
        
        let testData = Data(repeating: 0xCD, count: numberOfBytes)
        let chunks = try TransportFrame.chunkedFrame(from: testData, maxChunkSize: maxChunkSize)
        
        XCTAssertEqual(chunks.count, expectedNumberOfChunks)
    }
}
