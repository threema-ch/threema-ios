import Foundation

/// Implementation of `extra.transport.frame`
///
/// This adds or removes the leading 4 bytes that define the size of the rest of the data in little endian. If the size
/// is removed it is also validated.
enum TransportFrame {
    typealias Frame = Data
    typealias Chunk = Data
    
    enum Error: Swift.Error {
        case sizeFieldTooShort
        case dataSizeMismatch
    }
    
    /// Chunked frame from `data`
    /// - Parameters:
    ///   - data: Data to convert to frame and split into chunks, if needed
    ///   - maxChunkSize: Maximum chunk size in bytes
    /// - Returns: Frame split in chunks
    /// - Throws: `Error.sizeFieldTooShort` if `data` is too big to be encoded in one frame
    static func chunkedFrame(from data: Data, maxChunkSize: Int) throws -> [Chunk] {
        let frame = try frame(from: data)
        
        var currentStartIndex = 0
        var chunks = [Chunk]()
        chunks.reserveCapacity((frame.count / maxChunkSize) + 1)
        
        // Split frame in chunks
        while currentStartIndex < frame.count {
            let currentEndIndex = min(currentStartIndex + maxChunkSize, frame.count)
            chunks.append(frame[currentStartIndex..<currentEndIndex])
            currentStartIndex = currentEndIndex
        }
        
        return chunks
    }
    
    // TODO: (IOS-3922) Implement concatenation of incoming chunked frame
    
    /// Create frame from `data`
    /// - Parameter data: Data to convert to frame
    /// - Returns: Frame of `data`
    /// - Throws: `Error.sizeFieldTooShort` if `data` is too big to be encoded in one frame
    private static func frame(from data: Data) throws -> Frame {
        guard data.count < UInt32.max else {
            throw Error.sizeFieldTooShort
        }
        
        let encodedFrameLength = UInt32(data.count).littleEndianData
        
        var data = data
        data.insert(contentsOf: encodedFrameLength, at: 0)
        
        return data
    }
    
    /// Decode frame
    /// - Parameter frame: Frame to decode
    /// - Returns: Decoded frame as `Data`
    /// - Throws: `Error.dataSizeMismatch` the frame size doesn't match the data
    static func data(from frame: Frame) throws -> Data {
        let uInt32Bytes = frame[..<MemoryLayout<UInt32>.size]
        let data = frame.dropFirst(MemoryLayout<UInt32>.size)
        
        let expectedSize: UInt32 = try uInt32Bytes.littleEndian()
        
        guard expectedSize == data.count else {
            throw Error.dataSizeMismatch
        }
        
        return data
    }
}
