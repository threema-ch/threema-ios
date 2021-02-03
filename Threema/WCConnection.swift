//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

import Foundation
import CocoaLumberjackSwift

enum WCConnectionState: Int {
    case new, connecting, serverHandshake, peerHandshake, connectionInfoSend, connectionInfoReceived, ready, disconnecting, disconnected
}

protocol WCConnectionDelegate: class {
    func currentWebClientSession() -> WebClientSession?
    func currentWCSession() -> WCSession
    func currentMessageQueue() -> WebMessageQueue
}

@objc public class WCConnection: NSObject, NSCoding {
    
    enum WebSocketCode: UInt16 {
        case closing = 1000
    }
    
    public enum WCConnectionStopReason: Int {
        case stop, delete, disable, replace, error, pause
    }
    
    var context: WebConnectionContext?
    var delegate: WCConnectionDelegate
    var wca: String?
    
    private(set) var connectionStatus: WCConnectionState = .new
    
    private var webClientConnectionQueue:DispatchQueue
    private var webClientRequestEventQueue:DispatchQueue
    private var webClientRequestMsgQueue:DispatchQueue
    private var webClientSendQueue:DispatchQueue
    
    private var freeDisconnect = true
    
    private var connectionInfoRequest: WebUpdateConnectionInfoRequest?
    private(set) var connectionInfoResponse: WebUpdateConnectionInfoResponse?
    
    private var responder_sender:OpaquePointer?
    private var responder_disconnect:OpaquePointer?
    private var responder_client:OpaquePointer?
    
    private var connectionWaitTimer: Timer?
    private var pingInterval: UInt32 = 30
    
    public init(delegate: WCSession) {
        self.delegate = delegate
        
        webClientConnectionQueue = DispatchQueue(label: "ch.threema.webClientConnectionQueue", attributes: [])
        webClientRequestEventQueue = DispatchQueue(label: "ch.threema.webClientRequestEventQueue", attributes: [])
        webClientRequestMsgQueue = DispatchQueue(label: "ch.threema.webClientRequestMsgQueue", attributes: [])
        webClientSendQueue = DispatchQueue(label: "ch.threema.webClientSendQueue", attributes: [])
    }
    
    // MARK: NSCoding
    required public init?(coder aDecoder: NSCoder) {
        // super.init(coder:) is optional, see notes below
        self.context = aDecoder.decodeObject(forKey: "context") as? WebConnectionContext
        self.delegate = aDecoder.decodeObject(forKey: "delegate") as! WCConnectionDelegate
        if let status = aDecoder.decodeObject(forKey: "connectionStatus") as? Int {
            self.connectionStatus = WCConnectionState.init(rawValue: status)!
            DDLogVerbose("Threema Web: Init from coder -> Set connection state to \(WCConnectionState.init(rawValue: status)!)")
        } else {
            self.connectionStatus = .disconnected
            DDLogVerbose("Threema Web: Init from coder no predefined status -> Set connection state to new")
        }
        webClientConnectionQueue = DispatchQueue(label: "ch.threema.webClientConnectionQueue", attributes: [])
        webClientRequestEventQueue = DispatchQueue(label: "ch.threema.webClientRequestEventQueue", attributes: [])
        webClientRequestMsgQueue = DispatchQueue(label: "ch.threema.webClientRequestMsgQueue", attributes: [])
        webClientSendQueue = DispatchQueue(label: "ch.threema.webClientSendQueue", attributes: [])
        
        self.wca = aDecoder.decodeObject(forKey: "wca") as? String
        if let free = aDecoder.decodeObject(forKey: "freeDisconnect") as? Bool {
            self.freeDisconnect = free
        } else {
            self.freeDisconnect = true
        }
        self.connectionInfoRequest = aDecoder.decodeObject(forKey: "connectionInfoRequest") as? WebUpdateConnectionInfoRequest
        self.connectionInfoResponse = aDecoder.decodeObject(forKey: "connectionInfoResponse") as?WebUpdateConnectionInfoResponse
        
        self.pingInterval = UInt32(aDecoder.decodeInt32(forKey: "pingInterval"))
    }
    
    public func encode(with aCoder: NSCoder) {
        // super.encodeWithCoder(aCoder) is optional, see notes below
        aCoder.encode(context, forKey: "context")
        aCoder.encode(delegate, forKey: "delegate")
        aCoder.encode(connectionStatus.rawValue, forKey: "connectionStatus")
        aCoder.encode(wca, forKey: "wca")
        aCoder.encode(freeDisconnect, forKey: "freeDisconnect")
        if connectionInfoRequest != nil {
            aCoder.encode(connectionInfoRequest, forKey: "connectionInfoRequest")
        }
        if connectionInfoResponse != nil {
            aCoder.encode(connectionInfoResponse, forKey: "connectionInfoResponse")
        }
        aCoder.encode(Int32(pingInterval), forKey: "pingInterval")
    }
}

extension WCConnection {
    // MARK: public functions
    
    func connect(authToken: Data?) {
        webClientConnectionQueue.async {
            
            salty_log_change_level(UInt8(LEVEL_OFF))
            salty_log_init(UInt8(LEVEL_OFF))
            
            if self.delegate.currentWebClientSession() == nil {
                ValidationLogger.shared().logString("Threema Web: Can't connect to web, webClientSession is nil")
                return
            }
            var r_keypair: OpaquePointer? = nil
            
            if let p = self.delegate.currentWebClientSession()!.privateKey {
                let u8PtrPrivateKey: UnsafePointer<UInt8> = p.withUnsafeBytes {
                    $0.bindMemory(to: UInt8.self).baseAddress!
                }
                r_keypair = salty_keypair_restore(u8PtrPrivateKey)
            } else {
                r_keypair = salty_keypair_new()
            }
            let loop = salty_event_loop_new()
            let remote = salty_event_loop_get_remote(loop)
            
            guard let initiatorPermanentPublicKey = self.delegate.currentWebClientSession()!.initiatorPermanentPublicKey else {
                DDLogError("InitiatorPermanentPublicKey is nil. Can not start web session.")
                self.delegate.currentWebClientSession()?.isConnecting = false
                WCSessionManager.shared.removeWCSessionFromRunning(self.delegate.currentWCSession())
                return
            }
            let ippk: UnsafePointer<UInt8> = initiatorPermanentPublicKey.withUnsafeBytes {
                $0.bindMemory(to: UInt8.self).baseAddress!
            }
            
            var at: UnsafePointer<UInt8>? = nil
            if authToken != nil {
                at = authToken!.withUnsafeBytes {
                    $0.bindMemory(to: UInt8.self).baseAddress!
                }
            }
            
            self.connectToWebClient(ippk: ippk, at: at, r_keypair: r_keypair!, loop: loop!, remote: remote!)
        }
    }
    
    func close(close: Bool, forget: Bool, sendDisconnect: Bool, reason: WCConnectionStopReason) {
        if connectionStatus != .disconnecting && self.connectionStatus != .disconnected {
            self.connectionStatus = .disconnecting
            DDLogVerbose("Threema Web: close -> Set connection state to \(self.connectionStatus)")
            
            self.connectionWaitTimer?.invalidate()
            self.connectionWaitTimer = nil
            
            context?.cancelTimer()
            
            delegate.currentWebClientSession()?.isConnecting = false
            
            removeWCSessionFromRunning(reason: reason, forget: forget)
                        
            if sendDisconnect {
                let messageData = WebUpdateConnectionDisconnectResponse.init(disconnectReason: reason.rawValue)
                DDLogVerbose("Threema Web: MessagePack -> Send update/connectionDisconnect")
                sendMessageToWeb(blacklisted: true, msgpack: messageData.messagePack(), true)
                DispatchQueue.main.async {
                    Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { (timer) in
                        self.saltyClientDisconnect(close: close)
                    }
                }
            } else {
                self.connectionStatus = .disconnected
                DDLogVerbose("Threema Web: close, sendDisconnect == false -> Set connection state to \(self.connectionStatus)")
                
                if responder_disconnect != nil {
                    saltyClientDisconnect(close: close)
                }
            }
        } else {
            removeWCSessionFromRunning(reason: reason, forget: forget)
        }
    }
    
    func sendMessageToWeb(blacklisted: Bool, msgpack: Data, _ connectionInfo: Bool = false) {
        webClientSendQueue.sync {
            if self.context != nil {
                let chunker = try! Chunker(id: self.context!.messageCounter, data: msgpack, chunkSize: 64*1024)
                var chunksToSend = [[UInt8]]()
                for chunk in chunker {
                    if blacklisted == false {
                        DDLogVerbose("Threema Web: Cunkcache --> Add message")
                    } else {
                        DDLogVerbose("Threema Web: Cunkcache --> Do not add, message is blacklisted")
                    }
                    self.context!.append(chunk: blacklisted == true ? nil : chunk)
                    chunksToSend.append(chunk)
                }
                self.context!.messageCounter = self.context!.messageCounter + 1
                DDLogVerbose("Threema Web: Message counter --> \(self.context!.messageCounter)")
                
                for chunk in chunksToSend {
                    self.sendChunk(chunk: chunk, msgpack: msgpack, connectionInfo: connectionInfo)
                }
            }
        }
    }
    
    func sendChunk(chunk: [UInt8], msgpack: Data?, connectionInfo: Bool) {
        do {
            var msgData = Data()
            try msgData.pack(chunk)
            if (responder_sender == nil) {
                ValidationLogger.shared().logString("Threema Web: sendChunk: response_sender is nil")
                return
            }
            if connectionStatus != .ready && !connectionInfo {
                ValidationLogger.shared()?.logString("Threema Web: sendChunk status is not ready")
                return
            }
            let success = salty_client_send_task_bytes(responder_sender, msgData.bytes, UInt32(msgData.bytes.count))
            if success == UInt8(SEND_OK.rawValue) {
                // msgpack is only set if message is not from chunkcache
                if msgpack != nil {
                    delegate.currentMessageQueue().processSendFinished(finishedData: msgpack)
                }
            }
        }
        catch {
            ValidationLogger.shared().logString("Threema Web: Error during create chunks")
            close(close: true, forget: false, sendDisconnect: false, reason: .error)
        }
    }
    
    func setWCConnectionStateToReady() {
        connectionStatus = .ready
        DDLogVerbose("Threema Web: setWCConnectionStateToReady -> Set connection state to \(connectionStatus)")
    }
    
    func setWCConnectionStateToConnectionInfoReceived() {
        connectionStatus = .connectionInfoReceived
        DDLogVerbose("Threema Web: setWCConnectionStateToConnectionInfoReceived -> Set connection state to \(connectionStatus)")
    }
}

extension WCConnection {
    // MARK: private functions
    
    private func connectToWebClient(ippk: UnsafePointer<UInt8>, at: UnsafePointer<UInt8>?, r_keypair: OpaquePointer, loop: OpaquePointer, remote: OpaquePointer) {
        var client_ret: salty_relayed_data_client_ret_t? = nil
        
        let serverPermanentPublicKey = delegate.currentWebClientSession()!.serverPermanentPublicKey
        
        let u8PtrServerPermanentPublicKey: UnsafePointer<UInt8> = serverPermanentPublicKey!.withUnsafeBytes {
            $0.bindMemory(to: UInt8.self).baseAddress!
        }
        
        if delegate.currentWebClientSession()!.privateKey == nil {
            let privateKey = salty_keypair_private_key(r_keypair)
            let privateKeyData: Data? = NSData.init(bytes: privateKey, length: 32) as Data
            WebClientSessionStore.shared.updateWebClientSession(session: delegate.currentWebClientSession()!, privateKey: privateKeyData!)
            delegate.currentWCSession().privateKey = privateKeyData
        }
        
        if at != nil {
            client_ret = salty_relayed_data_responder_new(r_keypair, remote, pingInterval, ippk, at, u8PtrServerPermanentPublicKey)
        } else {
            client_ret = salty_relayed_data_responder_new(r_keypair, remote, pingInterval, ippk, nil, u8PtrServerPermanentPublicKey)
        }
        
        responder_sender = client_ret!.sender_tx
        responder_disconnect = client_ret!.disconnect_tx
        responder_client = client_ret!.client
        
        if client_ret!.success != 0 {
            delegate.currentWebClientSession()!.isConnecting = false
            let errorString = String(format:"Threema Web: salty relayed data responder error", (client_ret?.success)!)
            ValidationLogger.shared().logString(errorString)
            WCSessionManager.shared.removeWCSessionFromRunning(delegate.currentWCSession())
            return
        }
        
        let saltyRTCHost: NSString = delegate.currentWebClientSession()!.saltyRTCHost! as NSString
        let saltyRTCPort = delegate.currentWebClientSession()!.saltyRTCPort!.intValue
        
        WebClientSessionStore.shared.updateWebClientSession(session: delegate.currentWebClientSession()!, lastConnection: Date())
        
        let salty_client_init_ret = salty_client_init(saltyRTCHost.utf8String, UInt16(saltyRTCPort), client_ret!.client, loop, UInt16(0), nil, 0)
            if salty_client_init_ret.success == UInt8(INIT_OK.rawValue) {
                ValidationLogger.shared().logString("Threema Web: salty client init success")
                ValidationLogger.shared().logString("Threema Web: Start EventDispatchQueue")
                self.requestEventDispatchQueue(responder_event: salty_client_init_ret.event_rx, responder_receiver: client_ret!.receiver_rx)
                // Connect to the SaltyRTC server, do the server and peer handshake and run the task loop.
                // This call will only return once the connection has been terminated.
                let connect_success = salty_client_connect(salty_client_init_ret.handshake_future, client_ret!.client, loop, salty_client_init_ret.event_tx, client_ret!.sender_rx, client_ret!.disconnect_rx)
                
                WebClientSessionStore.shared.updateWebClientSession(session: delegate.currentWebClientSession()!, lastConnection: Date())
                
                delegate.currentWebClientSession()!.isConnecting = false
                context?.cancelTimer()
                let errorString = String(format:"Threema Web: Connection ended with exit code %i", connect_success)
                connectionStatus = .disconnected
                DDLogVerbose("Threema Web: connectToWebClient -> Set connection state to \(connectionStatus)")
                ValidationLogger.shared().logString(errorString)
                
                salty_relayed_data_client_free(client_ret!.client);
                salty_channel_sender_tx_free(client_ret!.sender_tx);
                if self.freeDisconnect {
                    salty_channel_disconnect_tx_free(self.responder_disconnect); // only if web disconnect
                }
                salty_event_loop_free(loop);
                
                responder_sender = nil
                responder_disconnect = nil
                responder_client = nil
                
                freeDisconnect = true
                
                self.connectionInfoResponse = nil
                self.connectionInfoRequest = nil
            } else {
                delegate.currentWebClientSession()!.isConnecting = false
                let errorString = String(format:"Threema Web: salty client init error", salty_client_init_ret.success)
                ValidationLogger.shared().logString(errorString)
                WCSessionManager.shared.removeWCSessionFromRunning(delegate.currentWCSession())
            }
    }
    
    private func requestEventDispatchQueue(responder_event: OpaquePointer, responder_receiver: OpaquePointer) {
        webClientRequestEventQueue.async {
            let recv_event = salty_client_recv_event(responder_event, nil)
            if recv_event.success == UInt8(RECV_OK.rawValue) {
                let event = recv_event.event!
                switch event.pointee.event_type {
                case UInt8(EVENT_CONNECTING.rawValue):
                    ValidationLogger.shared().logString("Threema Web: EVENT_CONNECTING")
                    self.connectionStatus = .connecting
                    DDLogVerbose("Threema Web: EVENT_CONNECTING -> Set connection state to \(self.connectionStatus)")
                    break
                case UInt8(EVENT_SERVER_HANDSHAKE_COMPLETED.rawValue):
                    if event.pointee.peer_connected == true {
                        self.connectionStatus = .serverHandshake
                        DDLogVerbose("Threema Web: EVENT_SERVER_HANDSHAKE_COMPLETED -> Set connection state to \(self.connectionStatus)")
                    } else {
                        self.connectionStatus = .serverHandshake
                        DDLogVerbose("Threema Web: EVENT_SERVER_HANDSHAKE_COMPLETED -> Set connection state to \(self.connectionStatus)")
                        ValidationLogger.shared().logString("Threema Web: Peer not connected")
                        
                        // start timer and wait 10 seconds for peer
                        self.connectionWaitTimer?.invalidate()
                        DispatchQueue.main.async {
                            self.connectionWaitTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false, block: { (timer) in
                                self.connectionWaitTimer?.invalidate()
                                self.connectionWaitTimer = nil
                                ValidationLogger.shared().logString("Threema Web: Error peer is not connected")
                                self.close(close: true, forget: false, sendDisconnect: true, reason: .stop)
                            })
                        }
                    }
                    ValidationLogger.shared().logString("Threema Web: EVENT_SERVER_HANDSHAKE_COMPLETED")
                    break
                case UInt8(EVENT_PEER_HANDSHAKE_COMPLETED.rawValue):
                    self.connectionStatus = .peerHandshake
                    DDLogVerbose("Threema Web: EVENT_PEER_HANDSHAKE_COMPLETED -> Set connection state to \(self.connectionStatus)")
                    self.connectionWaitTimer?.invalidate()
                    self.connectionWaitTimer = nil
                    
                    ValidationLogger.shared().logString("Threema Web: EVENT_PEER_HANDSHAKE_COMPLETED")
                    ValidationLogger.shared().logString("Threema Web: Set current session to active")
                    DispatchQueue.main.async {
                        if let webClientSession = self.delegate.currentWebClientSession() {
                            WebClientSessionStore.shared.updateWebClientSession(session: webClientSession, active: true)
                        }
                    }
                    
                    // send connectionInfo
                    let tmpId = Data.init(count: 0)
                    let nonceData = "connectionidconnectionid".data(using: .utf8)
                    
                    let id: UnsafePointer<UInt8> = tmpId.withUnsafeBytes {
                        $0.bindMemory(to: UInt8.self).baseAddress!
                    }
                    
                    let nonce: UnsafePointer<UInt8> = nonceData!.withUnsafeBytes {
                        $0.bindMemory(to: UInt8.self).baseAddress!
                    }
                    
                    let encrypt_decrypt_ret_t = salty_client_encrypt_with_session_keys(self.responder_client, id, 0, nonce)
                    if encrypt_decrypt_ret_t.success == UInt8(ENCRYPT_DECRYPT_OK.rawValue) {
                        let connectionId = Data.init(bytes: encrypt_decrypt_ret_t.bytes, count: encrypt_decrypt_ret_t.bytes_len)
                        let newContext = WebConnectionContext.init(connectionId: connectionId, delegate: self)
                        newContext.unchunker.delegate = self.delegate.currentWCSession()
                        
                        self.connectionStatus = .connectionInfoSend
                        DDLogVerbose("Threema Web: EVENT_PEER_HANDSHAKE_COMPLETED -> Set connection state to \(self.connectionStatus)")
                        if self.context != nil {
                            newContext.previousConnectionContext = self.context
                            self.connectionInfoResponse = WebUpdateConnectionInfoResponse.init(currentId: connectionId, previousId: newContext.previousConnectionContext!.connectionId(), previousSequenceNumber: UInt32(newContext.previousConnectionContext!.incomingSequenceNumber))
                            
                            newContext.messageCounter = newContext.previousConnectionContext!.messageCounter
                            newContext.unchunker = newContext.previousConnectionContext!.unchunker
                            newContext.unchunker.delegate = self.delegate.currentWCSession()
                        } else {
                            self.connectionInfoResponse = WebUpdateConnectionInfoResponse.init(currentId: connectionId, previousId: nil, previousSequenceNumber: nil)
                        }
                        self.context = newContext
                        DDLogVerbose("Threema Web: MessagePack -> Send update/connectionInfo")
                        self.sendMessageToWeb(blacklisted: true, msgpack: self.connectionInfoResponse!.messagePack(), true)
                        
                        if self.connectionStatus == .connectionInfoReceived {
                            ValidationLogger.shared()?.logString("Threema Web: connectionInfoReceived maybeResume state: \(self.connectionStatus.rawValue)")
                            self.connectionStatus = .ready
                            DDLogVerbose("Threema Web: connectionStatus == .connectionInfoReceived -> Set connection state to \(self.connectionStatus)")
                            self.context!.connectionInfoRequest = self.connectionInfoRequest
                            self.connectionInfoRequest?.maybeResume(session: self.delegate.currentWCSession())
                        } else {
                            ValidationLogger.shared()?.logString("Threema Web: connectionInfo not received state: \(self.connectionStatus.rawValue)")
                        }
                        ValidationLogger.shared().logString("Threema Web: Start MsgDispatchQueue")
                        self.requestMsgDispatchQueue(responder_receiver: responder_receiver)
                    } else {
                        // stopp session because connectionid is empty
                        ValidationLogger.shared().logString("Threema Web: ENCRYPT_DECRYPT_ERROR")
                        self.close(close: true, forget: false, sendDisconnect: true, reason: .error)
                    }
                    break
                case UInt8(EVENT_PEER_DISCONNECTED.rawValue):
                    ValidationLogger.shared().logString("Threema Web: EVENT_PEER_DISCONNECTED")
                    self.close(close: true, forget: false, sendDisconnect: false, reason: .stop)
                    break
                default:
                    print("Threema Web: unexpected event type \(event.pointee.event_type)")
                    break
                }
                
                if event.pointee.event_type != UInt8(EVENT_PEER_DISCONNECTED.rawValue) {
                    self.requestEventDispatchQueue(responder_event: responder_event, responder_receiver: responder_receiver)
                } else {
                    salty_channel_event_rx_free(responder_event)
                }
            } else {
                print("Threema Web: received event error ", recv_event.success)
            }
            salty_client_recv_event_ret_free(recv_event)
        }
    }
    
    private func requestMsgDispatchQueue(responder_receiver: OpaquePointer) {
        webClientRequestMsgQueue.async {
            let recv_ret = salty_client_recv_msg(responder_receiver, nil)
            let success = recv_ret.success
            if success == UInt8(RECV_OK.rawValue) {
                let msg = recv_ret.msg!
                switch msg.pointee.msg_type {
                case UInt8(MSG_TASK.rawValue):
                    let count = JDI.ToInt(msg.pointee.msg_bytes_len)
                    
                    let bytesArray = self.convert(length: count, data: msg.pointee.msg_bytes)
                    let chunkedData = Data(bytesArray)
                    do {
                        let unpackedData = try chunkedData.unpack()
                        if (self.context != nil) {
                            try self.context!.unchunker.addChunk(bytes: unpackedData as! Data)
                            self.context!.incomingSequenceNumber = self.context!.incomingSequenceNumber + 1
                        }
                    } catch {
                        ValidationLogger.shared().logString("Something went wrong while unchunk data: \(error)")
                    }
                    salty_client_recv_msg_ret_free(recv_ret)
                    break
                case UInt8(MSG_CLOSE.rawValue):
                    ValidationLogger.shared().logString("Threema Web: MSG_CLOSE")
                    salty_client_recv_msg_ret_free(recv_ret)
                    break
                default:
                    salty_client_recv_msg_ret_free(recv_ret)
                    break
                }
            }
            
            if success != UInt8(RECV_STREAM_ENDED.rawValue) && success != UInt8(RECV_ERROR.rawValue) {
                self.requestMsgDispatchQueue(responder_receiver: responder_receiver)
            } else {
                salty_channel_receiver_rx_free(responder_receiver)
            }
        }
    }
    
    private func removeWCSessionFromRunning(reason: WCConnectionStopReason, forget: Bool) {
        if reason != .pause && reason != .replace {
            ValidationLogger.shared().logString("Threema Web: Set current session by stop to inactive")
            WCSessionManager.shared.removeWCSessionFromRunning(delegate.currentWCSession())
            if forget, let webclientSession = delegate.currentWebClientSession() {
                WebClientSessionStore.shared.deleteWebClientSession(webclientSession)
            }
        }
    }
    
    private func saltyClientDisconnect(close: Bool) {
        let disconnectSuccess = salty_client_disconnect(self.responder_disconnect, WebSocketCode.closing.rawValue)
        if disconnectSuccess == UInt8(DISCONNECT_OK.rawValue) || disconnectSuccess == UInt8(DISCONNECT_ERROR.rawValue) {
            self.freeDisconnect = false
        }
        
        if close {
            self.context = nil
        }
        self.connectionStatus = .disconnected
        DDLogVerbose("Threema Web: close -> Set connection state to \(self.connectionStatus)")
    }
}

extension WCConnection {
    // MARK: Helper functions
    
    private func convert(length: Int, data: UnsafePointer<UInt8>) -> [UInt8] {
        let buffer = UnsafeBufferPointer(start: data, count: length);
        return Array(buffer)
    }
}

extension WCConnection: WebConnectionContextDelegate {
    internal func currentWCSession() -> WCSession {
        return delegate.currentWCSession()
    }
}

public class JDI {
    // To Int
    public static func ToInt(_ x : Int8) -> Int {
        return Int(x)
    }
    public static func ToInt(_ x : Int32) -> Int {
        return Int(x)
    }
    public static func ToInt(_ x : Int64) -> Int {
        return Int(truncatingIfNeeded: x)
    }
    public static func ToInt(_ x : Int) -> Int {
        return x
    }
    public static func ToInt(_ x : UInt8) -> Int {
        return Int(x)
    }
    public static func ToInt(_ x : UInt32) -> Int {
        if MemoryLayout<Int>.size == MemoryLayout<Int32>.size {
            return Int(Int32(bitPattern: x))  // For 32-bit systems, non-authorized interpretation
        }
        return Int(x)
    }
    public static func ToInt(_ x : UInt64) -> Int {
        return Int(truncatingIfNeeded: x)
    }
    public static func ToInt(_ x : UInt) -> Int {
        return Int(bitPattern: x)
    }

    // To UInt
    public static func ToUInt(_ x : Int8) -> UInt {
        return UInt(bitPattern: Int(x))  // Extend sign bit, assume minus input significant
    }
    public static func ToUInt(_ x : Int32) -> UInt {
        return UInt(truncatingIfNeeded: Int64(x))  // Extend sign bit, assume minus input significant
    }
    public static func ToUInt(_ x : Int64) -> UInt {
        return UInt(truncatingIfNeeded: x)
    }
    public static func ToUInt(_ x : Int) -> UInt {
        return UInt(bitPattern: x)
    }
    public static func ToUInt(_ x : UInt8) -> UInt {
        return UInt(x)
    }
    public static func ToUInt(_ x : UInt32) -> UInt {
        return UInt(x)
    }
    public static func ToUInt(_ x : UInt64) -> UInt {
        return UInt(truncatingIfNeeded: x)
    }
    public static func ToUInt(_ x : UInt) -> UInt {
        return x
    }
}

extension String {
    var unsafePointer: UnsafePointer<Int8> {
        return UnsafePointer((self as NSString).utf8String!)
    }
}
