//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

enum ChunkCacheError: Error {
    case invalidSequenceNumber
    case timeTravelForewards
    case timeTravelBackwards
}

class WebChunkCache: NSObject, NSCoding {
    
    private var _sequenceNumber: WebSequenceNumber
    private var _byteLength = 0
    private var cache = [[UInt8]?]()
    
    init(sequenceNumber: WebSequenceNumber) {
        self._sequenceNumber = sequenceNumber
    }
    
    func sequenceNumber() -> WebSequenceNumber {
        _sequenceNumber
    }
    
    func byteLength() -> Int {
        _byteLength
    }
    
    func chunks() -> [[UInt8]?] {
        cache
    }
    
    func transfer(fromCache: [[UInt8]?]) {
        DDLogVerbose("[Threema Web] Web Chunk Cache --> start transfer cache")
        let tmpCache = cache.compactMap { $0 }
        cache = tmpCache
        for chunk in fromCache {
            if chunk != nil {
                append(chunk: chunk)
            }
        }
        DDLogVerbose("[Threema Web] Web Chunk Cache --> end transfer cache")
    }
    
    func append(chunk: [UInt8]?) {
        if chunk != nil {
            _byteLength = _byteLength + chunk!.count
        }
        cache.append(chunk)
        _ = _sequenceNumber.increment()
        DDLogVerbose("[Threema Web] Web Chunk Cache --> \(_sequenceNumber.value)")
    }
    
    func prune(theirSequenceNumber: UInt32) throws {
        if sequenceNumber().isValid(other: UInt64(theirSequenceNumber)) == false {
            // error: Remote sent us an invalid sequence number
            throw ChunkCacheError.invalidSequenceNumber
        }
        
        // Calculate the slice start index for the chunk cache
        // Important: Our sequence number is one chunk ahead!
        
        let offset = Int64(theirSequenceNumber) - Int64(_sequenceNumber.value)
        if offset > 0 {
            // error: Remote travelled through time and acknowledged a chunk which is in the future
            ValidationLogger.shared()?
                .logString(
                    "[Threema Web] Prune Cache Error timeTravelForewards --> their: \(Int64(theirSequenceNumber)) my: \(Int64(_sequenceNumber.value))"
                )
            throw ChunkCacheError.timeTravelForewards
        }
        else if -offset > cache.count {
            // error: Remote travelled back in time and acknowledged a chunk it has already acknowledged
            ValidationLogger.shared()?
                .logString(
                    "[Threema Web] Prune Cache Error timeTravelBackwards --> their: \(Int64(theirSequenceNumber)) my: \(Int64(cache.count))"
                )
            throw ChunkCacheError.timeTravelBackwards
        }
        ValidationLogger.shared()?
            .logString(
                "[Threema Web] Prune Cache --> their: \(Int64(theirSequenceNumber)) my: \(Int64(_sequenceNumber.value))"
            )
        
        let endOffset = Int(Int64(cache.count) + offset)
        
        if endOffset == cache.count {
            cache = [[UInt8]]()
            _byteLength = 0
        }
        else {
            let removedChunks = cache[..<endOffset]
            let tmpCache = cache
            cache = Array(tmpCache.dropFirst(endOffset))
            for chunk in removedChunks {
                if chunk != nil {
                    _byteLength = _byteLength - chunk!.count
                }
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        // super.init(coder:) is optional, see notes below
        self._sequenceNumber = aDecoder.decodeObject(forKey: "_sequenceNumber") as! WebSequenceNumber
        self._byteLength = aDecoder.decodeInteger(forKey: "_byteLength")
        
        let tmpCache = aDecoder.decodeObject(forKey: "cache")
        if tmpCache is [[UInt8]?] {
            self.cache = aDecoder.decodeObject(forKey: "cache") as! [[UInt8]?]
        }
        else {
            self.cache = [[UInt8]?]()
        }
    }
    
    func encode(with aCoder: NSCoder) {
        // super.encodeWithCoder(aCoder) is optional, see notes below
        aCoder.encode(_sequenceNumber, forKey: "_sequenceNumber")
        aCoder.encode(_byteLength, forKey: "_byteLength")
        aCoder.encode(cache, forKey: "cache")
    }
}
