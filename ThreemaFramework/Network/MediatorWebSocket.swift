//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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
import Starscream

@objc public class MediatorWebSocket: NSObject, SocketProtocol {
    
    enum MediatorWebSocketError: Error {
        case invalidServerURL
    }
    
    fileprivate let server: String
    fileprivate let delegate: SocketProtocolDelegate
    private let queue: DispatchQueue?

    fileprivate var socket: WebSocket?
    fileprivate var readLength: UInt32?
    fileprivate var readTag: Int16?
    fileprivate var writeTag: Int16?
    
    var isIPv6: Bool {
        false
    }

    var isProxyConnection: Bool {
        false
    }

    required init(
        server: String,
        ports: [Int],
        preferIPv6: Bool,
        delegate: SocketProtocolDelegate,
        queue: DispatchQueue?
    ) throws {
        self.server = server
        self.delegate = delegate
        self.queue = queue

        super.init()

        guard let serverURL = URL(string: server) else {
            throw MediatorWebSocketError.invalidServerURL
        }
        
        self.socket = WebSocket(url: serverURL)
        socket?.delegate = self
    }
    
    @objc func read(length: UInt32, timeout: Int16, tag: Int16) {
        readLength = length
        readTag = tag
    }
    
    @objc public func write(data: Data, tag: Int16) {
        writeTag = tag
        write(data: MediatorMessageProtocol.addProxyCommonHeader(data))
    }
    
    public func write(data: Data) {
        guard let socket = socket, socket.isConnected else {
            return
        }
        socket.write(data: data)
    }
    
    @objc func connect() -> Bool {
        if let socket = socket,
           !socket.isConnected {
            
            socket.connect()
        }
        return true
    }
    
    @objc func disconnect() {
        if let socket = socket,
           socket.isConnected {
            
            socket.disconnect()
        }
    }
}

// MARK: - WebSocketDelegate

extension MediatorWebSocket: WebSocketDelegate {
    public func websocketDidConnect(socket: WebSocketClient) {
        delegate.didConnect()
    }
    
    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        if let error = error as? WSError {
            DDLogError(
                "Disconnect with error: \(error.localizedDescription). Error code: \(error.code); Error Message: \(error.message)"
            )
        }
        else if let error = error {
            DDLogError("Disconnect with error: \(error.localizedDescription)")
        }
        
        delegate.didDisconnect()
    }
    
    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        DDLogVerbose("Received text message: \(text)")
    }

    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        guard let tag = readTag else {
            DDLogVerbose("No tag set for received data")
            return
        }

        if MediatorMessageProtocol.isMediatorMessage(data) {
            // Handle mediator message
            delegate.didRead(data, tag: 8)
        }
        else {
            // Handle chat message
            if tag == 6 { // TODO: Define tags as constant
                let (message, length) = MediatorMessageProtocol.extractChatMessageAndLength(data)
                if message != nil, length != nil {
                    delegate.didRead(message!, tag: 7)
                }
            }
            else {
                delegate.didRead(MediatorMessageProtocol.extractChatMessage(data), tag: tag)
            }
        }
    }
}
