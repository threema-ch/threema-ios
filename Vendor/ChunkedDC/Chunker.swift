/**
 * Copyright (c) 2018 Threema GmbH / SaltyRTC Contributors
 *
 * Licensed under the Apache License, Version 2.0, <see LICENSE-APACHE file> or
 * the MIT license <see LICENSE-MIT file>, at your option. This file may not be
 * copied, modified, or distributed except according to those terms.
 */

import Foundation

/// All errors that can occur inside the `Chunker`.
enum ChunkerError: Error {
    /// The chunk size must be at least 10 bytes.
    case chunkSizeTooSmall

    /// The data to be chunked must not be empty.
    case dataEmpty
}

/// Create a new chunk.
func makeChunkBytes(id: UInt32, serial: UInt32, endOfMessage: Bool, data: ArraySlice<UInt8>) -> [UInt8] {
    var chunk = [UInt8](repeating: 0, count: data.count + Int(Common.headerLength))

    // Write options
    let options: UInt8 = endOfMessage ? 1 : 0
    chunk[0] = options

    // Write id
    chunk[1] = UInt8((id >> 24) & 0xff)
    chunk[2] = UInt8((id >> 16) & 0xff)
    chunk[3] = UInt8((id >> 8) & 0xff)
    chunk[4] = UInt8(id & 0xff)

    // Write serial
    chunk[5] = UInt8((serial >> 24) & 0xff)
    chunk[6] = UInt8((serial >> 16) & 0xff)
    chunk[7] = UInt8((serial >> 8) & 0xff)
    chunk[8] = UInt8(serial & 0xff)

    // Write chunk data
    chunk[9..<9+data.count] = ArraySlice(data)

    return chunk
}

/// A `Chunker` splits up a `Data` instance into multiple chunks.
///
/// The `Chunker` is initialized with an ID. For each message to be chunked, a
/// new `Chunker` instance is required.
///
/// This type implements `Sequence` and `IteratorProtocol`, so it can be
/// iterated over (but only once, after which it has been consumed).
class Chunker: Sequence, IteratorProtocol {
    private let id: UInt32
    private let data: Data
    private let chunkDataSize: UInt32
    private var chunkId: UInt32 = 0

    init(id: UInt32, data: Data, chunkSize: UInt32) throws {
        if chunkSize < Common.headerLength + 1 {
            throw ChunkerError.chunkSizeTooSmall
        }
        if data.isEmpty {
            throw ChunkerError.dataEmpty
        }
        self.id = id
        self.data = data
        self.chunkDataSize = chunkSize - Common.headerLength
    }

    func hasNext() -> Bool {
        let currentIndex = chunkId * chunkDataSize
        let remaining = data.count - Int(currentIndex)
        return remaining >= 1
    }

    func next() -> [UInt8]? {
        if !self.hasNext() {
            return nil
        }

        // Create next chunk
        let currentIndex = Int(self.chunkId * self.chunkDataSize)
        let remaining = self.data.count - currentIndex
        let effectiveChunkDataSize = Swift.min(remaining, Int(self.chunkDataSize))
        let endOfMessage = remaining <= effectiveChunkDataSize
        let chunk = makeChunkBytes(
            id: self.id,
            serial: self.nextSerial(),
            endOfMessage: endOfMessage,
            data: ArraySlice(self.data[currentIndex ..< currentIndex+effectiveChunkDataSize])
        )

        return chunk
    }

    func makeIterator() -> Chunker {
        return self
    }

    /// Return and post-increment the id of the next block
    private func nextSerial() -> UInt32 {
        let serial = self.chunkId
        self.chunkId += 1
        return serial
    }
}
