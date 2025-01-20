//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

protocol WebConnectionContextDelegate: WCConnection {
    func currentWCSession() -> WCSession
}

class WebConnectionContext: NSObject, NSCopying {
    var delegate: WebConnectionContextDelegate
    var chunkCache = WebChunkCache(sequenceNumber: WebSequenceNumber(minValue: 0, maxValue: UInt64(UINT32_MAX)))
    var connectionInfoRequest: WebUpdateConnectionInfoRequest?
    var unchunker = Unchunker()
    var messageCounter: UInt32 = 0
    var incomingSequenceNumber: UInt32 = 0
    var cacheTimer: Timer?
    var previousConnectionContext: WebConnectionContext? {
        get {
            _previousContext
        }
        set(previous) {
            _previousContext = previous
            _previousContext?.previousConnectionContext = nil
        }
    }
    
    private var _connectionID: Data
    private var _previousContext: WebConnectionContext?
    
    init(connectionID: Data, delegate: WCConnection) {
        self._connectionID = connectionID
        self.delegate = delegate
    }
    
    init(
        connectionID: Data,
        chunkCache: WebChunkCache,
        connectionInfoRequest: WebUpdateConnectionInfoRequest?,
        unchunker: Unchunker,
        messageCounter: UInt32,
        incomingSequenceNumber: UInt32,
        cacheTimer: Timer?,
        delegate: WCConnection
    ) {
        self.chunkCache = chunkCache
        self.connectionInfoRequest = connectionInfoRequest
        self.unchunker = unchunker
        self.messageCounter = messageCounter
        self.incomingSequenceNumber = incomingSequenceNumber
        self.cacheTimer = cacheTimer
        self._connectionID = connectionID
        self.delegate = delegate
    }
    
    func connectionID() -> Data {
        _connectionID
    }
    
    func runTimer() {
        cacheTimer?.invalidate()

        DispatchQueue.main.async {
            self.cacheTimer = Timer.scheduledTimer(
                timeInterval: 10,
                target: self,
                selector: #selector(self.sendConnectionAck),
                userInfo: nil,
                repeats: true
            )
        }
    }
    
    func cancelTimer() {
        cacheTimer?.invalidate()
        cacheTimer = nil
    }
    
    @objc func sendConnectionAck() {
        let responseConnectionAck = WebConnectionAckUpdateResponse(
            requestID: nil,
            incomingSequenceNumber: incomingSequenceNumber
        )
        DDLogVerbose("[Threema Web] MessagePack -> Send update/connectionAck")
        if delegate.currentWCSession().connectionStatus() == .ready {
            delegate.currentWCSession()
                .sendMessageToWeb(blacklisted: true, msgpack: responseConnectionAck.messagePack())
        }
    }
    
    func transfer(fromCache: [[UInt8]?]) {
        chunkCache.transfer(fromCache: fromCache)
    }
    
    func append(chunk: [UInt8]?) {
        chunkCache.append(chunk: chunk)
    }
    
    func prune(theirSequenceNumber: UInt32) throws {
        try chunkCache.prune(theirSequenceNumber: theirSequenceNumber)
    }
    
    func updateUnchunker(oldUnchunker: Unchunker) {
        let unchunkerSerialize: [[UInt8]] = oldUnchunker.serialize()
        for chunk in unchunkerSerialize {
            let chunkData = Data(chunk)
            do {
                try unchunker.addChunk(bytes: chunkData)
            }
            catch {
                // error can't add old chunk
            }
        }
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = WebConnectionContext(
            connectionID: _connectionID,
            chunkCache: chunkCache,
            connectionInfoRequest: connectionInfoRequest,
            unchunker: unchunker,
            messageCounter: messageCounter,
            incomingSequenceNumber: incomingSequenceNumber,
            cacheTimer: cacheTimer,
            delegate: delegate as WCConnection
        )
        return copy
    }
}
