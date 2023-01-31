//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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

class WebUpdateConnectionInfoRequest: NSObject, NSCoding {
    
    let id: Data
    let resume: WebConnection?
    
    init(message: WebAbstractMessage) {
        let data = message.data as! [AnyHashable: Any?]
        self.id = data["id"] as! Data
        if let tmpResume = data["resume"] as? [String: Any] {
            self.resume = WebConnection(connection: tmpResume)
        }
        else {
            self.resume = nil
        }
    }
    
    func maybeResume(session: WCSession) {
        if let connectionInfoResponse = session.connectionInfoResponse() {
            if connectionInfoResponse.id != id {
                ValidationLogger.shared().logString("[Threema Web] Wrong connection id, stop session.")
                session.stop(close: true, forget: false, sendDisconnect: true, reason: .error)
                return
            }
            
            if resume != nil, let context = session.connectionContext() {
                if context.previousConnectionContext?.connectionID() == resume!.id {
                    do {
                        // should be previousContext
                        try context.previousConnectionContext?.prune(theirSequenceNumber: resume!.sequenceNumber!)
                    }
                    catch {
                        // do error stuff
                        ValidationLogger.shared().logString("[Threema Web] Could not prune cache: \(error).")
                        session.stop(close: true, forget: false, sendDisconnect: true, reason: .error)
                        return
                    }
                    
                    if session.connectionStatus() == .ready {
                        if context.previousConnectionContext != nil {
                            context.transfer(fromCache: context.previousConnectionContext!.chunkCache.chunks())
                            ValidationLogger.shared()
                                .logString("[Threema Web] Transfer \(context.chunkCache.chunks().count) chunks.")
                            for chunk in context.chunkCache.chunks() {
                                session.sendChunk(chunk: chunk!, msgpack: nil, connectionInfo: false)
                            }
                            context.updateUnchunker(oldUnchunker: context.previousConnectionContext!.unchunker)
                            context.previousConnectionContext = nil
                        }
                        session.messageQueue.processQueue()
                        context.runTimer()
                    }
                    ValidationLogger.shared().logString("[Threema Web] Resume connection.")
                    let responseBatteryStatus = WebBatteryStatusUpdate()
                    session.sendMessageToWeb(blacklisted: true, msgpack: responseBatteryStatus.messagePack())
                    DDLogVerbose("[Threema Web] MessagePack -> Send update/batteryStatus")
                    return
                }
            }
            
            if resume == nil {
                ValidationLogger.shared().logString("[Threema Web] Resume is nil.")
            }
            if session.connectionContext() == nil {
                ValidationLogger.shared().logString("[Threema Web] Connection context is nil.")
            }
            // do not resume
            session.clearAllRequestedLists()
            if session.connectionStatus() == .ready {
                ValidationLogger.shared()
                    .logString(
                        "[Threema Web] Connection state is ready -> process queue and reset previous connection context."
                    )
                session.messageQueue.processQueue()
                session.connectionContext()?.previousConnectionContext = nil
                session.connectionContext()?.runTimer()
            }
            return
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.id = aDecoder.decodeObject(forKey: "id") as! Data
        self.resume = aDecoder.decodeObject(forKey: "resume") as? WebConnection
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: "id")
        aCoder.encode(resume, forKey: "resume")
    }
}

class WebConnection: NSObject, NSCoding {
    var id: Data
    var sequenceNumber: UInt32? // chunk id
    
    init(connection: [String: Any]) {
        self.id = connection["id"] as! Data
        if connection["sequenceNumber"] != nil {
            self.sequenceNumber = WebConnection.convertToUInt32(sn: connection["sequenceNumber"]!)
        }
    }
    
    // MARK: NSCoding

    public required init?(coder aDecoder: NSCoder) {
        self.id = aDecoder.decodeObject(forKey: "id") as! Data
        self.sequenceNumber = UInt32(aDecoder.decodeInt32(forKey: "sequenceNumber"))
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: "id")
        if sequenceNumber != nil {
            aCoder.encode(Int32(sequenceNumber!), forKey: "sequenceNumber")
        }
    }
    
    func objectDict() -> [String: Any] {
        ["id": id, "sequenceNumber": sequenceNumber ?? 0]
    }
    
    class func convertToUInt32(sn: Any) -> UInt32 {
        var converted: UInt32 = 0
        if let sq = sn as? UInt8 {
            converted = UInt32(sq)
        }
        else if let sq = sn as? Int8 {
            converted = UInt32(sq)
        }
        else if let sq = sn as? UInt16 {
            converted = UInt32(sq)
        }
        else if let sq = sn as? Int16 {
            converted = UInt32(sq)
        }
        else if let sq = sn as? UInt32 {
            converted = sq
        }
        else if let sq = sn as? Int32 {
            converted = UInt32(sq)
        }
        else if let sq = sn as? UInt64 {
            if sq > UINT32_MAX {
                // error
            }
            else {
                converted = UInt32(sq)
            }
        }
        else if let sq = sn as? Int64 {
            if sq > UINT32_MAX {
                // error
            }
            else {
                converted = UInt32(sq)
            }
        }
        else {
            // error
        }
        return converted
    }
}

extension Data {
    
    /// Hexadecimal string representation of `Data` object.
    
    var hexadecimal: String {
        map { String(format: "%02x", $0) }
            .joined()
    }
}
