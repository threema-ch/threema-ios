/**
 * Copyright (c) 2018 Threema GmbH / SaltyRTC Contributors
 *
 * Licensed under the Apache License, Version 2.0, <see LICENSE-APACHE file> or
 * the MIT license <see LICENSE-MIT file>, at your option. This file may not be
 * copied, modified, or distributed except according to those terms.
 */

import Foundation

/// All errors that can occur inside the `Unchunker`.
enum UnchunkerError: Error {
    /// Not all chunks for a message have arrived yet
    case messageNotYetComplete
    /// A chunk collector can only collect chunks belonging to the same message
    case inconsistentMessageId
    /// Chunk is smaller than the header length
    case chunkTooSmall
}

/// Delegate that will be called with the assembled message once all chunks arrived.
protocol MessageCompleteDelegate: AnyObject {
    func messageComplete(message: Data)
}

/// A chunk.
struct Chunk {
    let endOfMessage: Bool
    let id: UInt32
    let serial: UInt32
    let data: [UInt8]

    /// Create a new chunk.
    init(endOfMessage: Bool, id: UInt32, serial: UInt32, data: [UInt8]) {
        self.endOfMessage = endOfMessage
        self.id = id
        self.serial = serial
        self.data = data
    }

    /// Parse bytes into a chunk.
    /// Throws an `UnchunkerError` if the chunk is smaller than the header length.
    init(bytes: Data) throws {
        if bytes.count < Common.headerLength {
            throw UnchunkerError.chunkTooSmall
        }

        // Read header
        let options: UInt8 = bytes[0]
        self.endOfMessage = (options & 0x01) == 1
        self.id = (UInt32(bytes[1]) << 24) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 8) | UInt32(bytes[4])
        self.serial = (UInt32(bytes[5]) << 24) | (UInt32(bytes[6]) << 16) | (UInt32(bytes[7]) << 8) | UInt32(bytes[8])

        // Read data
        self.data = [UInt8](bytes[9..<bytes.count])
    }

    func serialize() -> [UInt8] {
        return makeChunkBytes(
            id: self.id,
            serial: self.serial,
            endOfMessage: self.endOfMessage,
            data: ArraySlice(self.data)
        )
    }
}

extension Chunk: Comparable {
    static func < (lhs: Chunk, rhs: Chunk) -> Bool {
        if lhs.id == rhs.id {
            return lhs.serial < rhs.serial
        } else {
            return lhs.id < rhs.id
        }
    }

    static func == (lhs: Chunk, rhs: Chunk) -> Bool {
        return lhs.endOfMessage == rhs.endOfMessage
            && lhs.id == rhs.id
            && lhs.serial == rhs.serial
            && lhs.data == rhs.data
    }
}

/// A chunk collector collects chunk belonging to the same message.
///
/// This class is thread safe.
class ChunkCollector {
    private var endArrived: Bool = false
    private var messageLength: Int?
    private var chunks: [Chunk] = []
    private var lastUpdate = Date()
    private let serialQueue = DispatchQueue(label: "chunkCollector")

    var count: Int {
        get { return self.chunks.count }
    }

    /// Register a new incoming chunk for this message.
    func addChunk(chunk: Chunk) throws {
        try self.serialQueue.sync {
            // Make sure that chunk belongs to the same message
            if !self.chunks.isEmpty && chunk.id != self.chunks[0].id {
                throw UnchunkerError.inconsistentMessageId
            }

            // Store the chunk
            self.chunks.append(chunk)

            // Update internal state
            self.lastUpdate = Date()
            if chunk.endOfMessage {
                self.endArrived = true
                self.messageLength = Int(chunk.serial) + 1
            }
        }
    }

    /// Return whether the collector contains the chunk with the specified serial
    func contains(serial: UInt32) -> Bool {
        return self.chunks.contains(where: { $0.serial == serial })
    }

    /// Return whether the message is complete, meaning that all chunks of the message arrived.
    func isComplete() -> Bool {
        return self.endArrived
            && self.chunks.count == self.messageLength
    }

    /// Return whether last chunk is older than the specified interval.
    func isOlderThan(interval: TimeInterval) -> Bool {
        let age = Date().timeIntervalSince(self.lastUpdate)
        return age > interval
    }

    /// Merge the chunks into a complete message.
    ///
    /// :returns: The assembled message `Data`
    func merge() throws -> Data {
        return try self.serialQueue.sync {
            // Preconditions
            if !self.isComplete() {
                throw UnchunkerError.messageNotYetComplete
            }

            // Sort chunks in-place
            self.chunks.sort()

            // Allocate buffer
            let capacity = self.chunks[0].data.count * self.messageLength!
            var data = Data(capacity: capacity)

            // Add chunks to buffer
            for chunk in self.chunks {
                data.append(contentsOf: chunk.data)
            }

            return data
        }
    }

    /// Return list of serialized chunks.
    ///
    /// Note that the "last update" timestamps will not be serialized, only the raw chunks!
    func serialize() -> [[UInt8]] {
        return self.serialQueue.sync {
            self.chunks.map({ $0.serialize() })
        }
    }
}

/// An Unchunker instance merges multiple chunks into a single `Data`.
class Unchunker {
    weak var delegate: MessageCompleteDelegate?
    private var chunks: [UInt32: ChunkCollector] = [:]
    private let serialQueue = DispatchQueue(label: "unchunker")

    /// Add a chunk.
    ///
    /// :bytes: Data containing chunk with 9 byte header
    func addChunk(bytes: Data) throws {
        return try self.serialQueue.sync {
            let chunk = try Chunk(bytes: bytes)

            // Ignore repeated chunks with the same serial
            if self.chunks.contains(where: { id, collector in
                id == chunk.id && collector.contains(serial: chunk.serial)
            }) {
                return
            }

            // If this is the only chunk in the message, return it immediately.
            if chunk.endOfMessage && chunk.serial == 0 {
                self.delegate?.messageComplete(message: Data(chunk.data))
                self.chunks.removeValue(forKey: chunk.id)
                return
            }

            // Otherwise, add chunk to chunks list
            let collector: ChunkCollector;
            switch self.chunks[chunk.id] {
            case nil:
                collector = ChunkCollector()
                self.chunks[chunk.id] = collector
            case let c?:
                collector = c
            }
            try collector.addChunk(chunk: chunk)

            // Check if message is complete
            if collector.isComplete() {
                // Merge and notify delegate...
                self.delegate?.messageComplete(message: try collector.merge())
                // ...the delete the chunks.
                self.chunks.removeValue(forKey: chunk.id)
            }
        }
    }

    /// Run garbage collection, remove incomplete messages that haven't been
    /// updated for more than the specified number of milliseconds.
    ///
    /// If you want to make sure that invalid chunks don't fill up memory, call
    /// this method regularly.
    ///
    /// :maxAge: Remove incomplete messages that haven't been updated for the specified interval.
    ///
    /// :returns: the number of removed chunks
    func gc(maxAge: TimeInterval) -> UInt {
        return self.serialQueue.sync {
            var removedItems: UInt = 0
            self.chunks = self.chunks.filter({ (_id, collector) in
                if collector.isOlderThan(interval: maxAge) {
                    removedItems += UInt(collector.count)
                    return false
                } else {
                    return true
                }
            })
            return removedItems
        }
    }

    /// Return list of serialized chunks.
    ///
    /// Note that the "last update" timestamps will not be serialized, only the raw chunks!
    func serialize() -> [[UInt8]] {
        return self.serialQueue.sync {
            return self.chunks.values.flatMap({ $0.serialize() })
        }
    }
}
