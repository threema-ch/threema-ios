//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
import ThreemaProtocols

/// Implementation of the Connection Rendezvous Protocol to establish a 1:1 connection between two devices
///
/// Currently on the Rendezvous Responder Device side is implemented that only works over a WebSocket and with a group
/// join request from the other device.
public enum RendezvousProtocol {
    
    public enum Error: Swift.Error {
        case unableToGenerateRandomData
        case unableToGenerateEphemeralTransportKeyPair
        case unableToDeserializeData
        case challengeMismatch
        case invalidProtocolMessage
        case unableToParseData
        case invalidVersion
        
        case notImplemented
    }
    
    // MARK: - Responder handshake
    
    /// Establish an encrypted rendezvous connection
    ///
    /// Note: We only support WebSocket relays and device join request for now
    ///
    /// - Parameters:
    ///   - urlSafeBase64DeviceGroupJoinRequestOffer: URL safe base64 encoded string of device group join request or
    ///                                               offer data
    ///   - isNominator: Should we choose the connection?
    ///   - encryptedRendezvousConnectionCreator: Helper to create the connection and crypto instance.
    ///                                           This is mainly for testing.
    /// - Returns: An established rendezvous connection that transparently en- and decrypts any data sent or received
    /// - Throws: `RendezvousProtocol.Error` or `EncryptedRendezvousConnectionError`
    static func connect(
        urlSafeBase64DeviceGroupJoinRequestOffer: String,
        isNominator: Bool,
        encryptedRendezvousConnectionCreator: EncryptedRendezvousConnectionCreator =
            DefaultEncryptedRendezvousConnectionCreator()
    ) async throws -> (connection: EncryptedRendezvousConnection, pathHash: Data) {
        DDLogNotice("Connect...")
        
        let rendezvousInit =
            try parseAndValidate(urlSafeBase64DeviceGroupJoinRequestOffer: urlSafeBase64DeviceGroupJoinRequestOffer)
        
        let (encryptedRendezvousConnection, crypto) = try encryptedRendezvousConnectionCreator
            .create(from: rendezvousInit)
        
        try encryptedRendezvousConnection.connect()
        
        let pathHash: Data
        do {
            pathHash = try await responderDeviceHandshake(
                for: encryptedRendezvousConnection,
                with: crypto,
                isNominator: isNominator
            )
        }
        catch {
            DDLogError("Handshake failed: \(error)")
            encryptedRendezvousConnection.close()
            throw error
        }
                
        DDLogNotice("Connect successful")
        
        return (encryptedRendezvousConnection, pathHash)
    }
    
    // MARK: - Private helper
    
    private static func parseAndValidate(
        urlSafeBase64DeviceGroupJoinRequestOffer: String
    ) throws -> Rendezvous_RendezvousInit {
        guard let deviceGroupJoinRequestOrOfferData = Data(
            urlSafeBase64Encoded: urlSafeBase64DeviceGroupJoinRequestOffer
        ) else {
            throw Error.unableToParseData
        }
        
        // swiftformat:disable:next acronyms
        guard let deviceGroupJoinRequestOrOffer = try? Url_DeviceGroupJoinRequestOrOffer(
            serializedData: deviceGroupJoinRequestOrOfferData
        ) else {
            throw Error.unableToDeserializeData
        }
        
        guard try validate(deviceGroupJoinRequestOrOffer: deviceGroupJoinRequestOrOffer) else {
            throw Error.invalidProtocolMessage
        }
            
        let rendezvousInit = deviceGroupJoinRequestOrOffer.rendezvousInit
        guard try validate(rendezvousInit: rendezvousInit) else {
            throw Error.invalidProtocolMessage
        }
        
        return rendezvousInit
    }
    
    // swiftformat:disable:next acronyms
    private static func validate(deviceGroupJoinRequestOrOffer: Url_DeviceGroupJoinRequestOrOffer) throws -> Bool {
        // 1. If `version` or `variant` is not supported, abort these steps.
        switch deviceGroupJoinRequestOrOffer.version {
        case .UNRECOGNIZED:
            throw Error.invalidVersion
        default:
            break
        }
        
        // Currently we only support request to join
        guard deviceGroupJoinRequestOrOffer.variant.type == .requestToJoin(.init()) else {
            return false
        }
        
        return true
    }
    
    private static func validate(rendezvousInit: Rendezvous_RendezvousInit) throws -> Bool {
        
        // 1. If `version` is unsupported, abort these steps.
        switch rendezvousInit.version {
        case .UNRECOGNIZED:
            throw Error.invalidVersion
        default:
            break
        }
        
        // 2. If any `path_id` is not unique, abort these steps.
        
        var pathIDs = Set<UInt32>()
        if rendezvousInit.hasRelayedWebSocket {
            let (inserted, _) = pathIDs.insert(rendezvousInit.relayedWebSocket.pathID)
            guard inserted else {
                return false
            }
        }
        
        if rendezvousInit.hasDirectTcpServer {
            for ipAddress in rendezvousInit.directTcpServer.ipAddresses {
                let (inserted, _) = pathIDs.insert(ipAddress.pathID)
                guard inserted else {
                    return false
                }
            }
        }
        
        return true
    }
    
    // MARK: - Responder handshake
    
    private static func responderDeviceHandshake(
        for connection: EncryptedRendezvousConnection,
        with crypto: RendezvousCrypto,
        isNominator: Bool
    ) async throws -> Data {
        guard let outgoingChallenge = BytesUtility.generateRandomBytes(length: Rendezvous.challengeLength) else {
            throw Error.unableToGenerateRandomData
        }
        
        guard let ephemeralTransportKeyPair = try? NaClCrypto.shared().generateNewKeyPair(),
              ephemeralTransportKeyPair.publicKey.count == Rendezvous.ephemeralPublicKeyLength else {
            throw Error.unableToGenerateEphemeralTransportKeyPair
        }
        
        // RRD ---- Handshake.RrdToRid.Hello ---> RID

        let helloMessage = Rendezvous_Handshake.RrdToRid.Hello.with {
            $0.challenge = outgoingChallenge
            $0.etk = ephemeralTransportKeyPair.publicKey
        }
        
        let helloMessageData = try helloMessage.serializedData()
        
        DDLogVerbose("Send hello: \(helloMessage)")
        try await connection.send(helloMessageData)
        
        // RRD <- Handshake.RidToRrd.AuthHello -- RID
        
        let authHelloData = try await connection.receive()
        let authHelloMessage = try Rendezvous_Handshake.RidToRrd.AuthHello(serializedData: authHelloData)
        // In theory we should retry to receive more data/frames and see if we the combined data can be deserialized.
        // For now we assume that this message is enough small
        DDLogVerbose("Received auth hello: \(authHelloMessage)")
        
        // 1. If the challenge `response` from RID does not match the challenge sent
        //    by RRD, abort the connection and these steps.
        guard authHelloMessage.response == outgoingChallenge else {
            throw Error.challengeMismatch
        }
        
        // RRD ---- Handshake.RrdToRid.Auth ----> RID

        let authMessage = Rendezvous_Handshake.RrdToRid.Auth.with {
            $0.response = authHelloMessage.challenge
        }
        
        let authMessageData = try authMessage.serializedData()
        
        DDLogVerbose("Send auth: \(authMessage)")
        try await connection.send(authMessageData)
        
        // Switch keys
        
        DDLogNotice("Handshake completed, switch to transport keys")
        let pathHash = try crypto.switchToTransportKeys(
            localEphemeralTransportKeyPair: ephemeralTransportKeyPair,
            remotePublicEphemeralTransportKey: authHelloMessage.etk
        )
        
        // R*D ------- Handshake.Nominate ------> R*D
        
        if isNominator {
            let nominateMessageData = try Rendezvous_Nominate().serializedData()
            
            DDLogNotice("Send nomination message")
            try await connection.send(nominateMessageData)
        }
        else {
            // Right now we don't support more than a WebSocket connection, thus we just wait for the message
            let _ = try await connection.receive()
            
            DDLogVerbose("Received a message")
            
            guard let _ = try? Rendezvous_Nominate(serializedData: authHelloData) else {
                throw Error.unableToDeserializeData
            }
        }
        
        DDLogNotice("Rendezvous completed!")
        
        return pathHash
    }
    
    // MARK: - Initiator handshake (not implemented)
    
    // Sketch for a initiator implementation:
    // 1. Create connection
    // 2. Send init info via async sequence
    // 3. Wait for handshake
    // 4. Send connection as closing state over async sequence
    
    // TODO: This is not correct
    private static func ridHandshake(
        for connection: EncryptedRendezvousConnection,
        with crypto: RendezvousCrypto
    ) async throws -> Data {
        throw Error.notImplemented
        
        guard let outgoingChallenge = BytesUtility.generateRandomBytes(length: Rendezvous.challengeLength) else {
            throw Error.unableToGenerateRandomData
        }
        
        let ephemeralTransportKeyPair = try NaClCrypto.shared().generateNewKeyPair()
        assert(ephemeralTransportKeyPair.publicKey.count == Rendezvous.ephemeralPublicKeyLength)

        //     RRD ---- Handshake.RrdToRid.Hello ---> RID

        let helloData = try await connection.receive()
        
        let helloMessage = try Rendezvous_Handshake.RrdToRid.Hello(serializedData: helloData)
        
        DDLogVerbose("Received hello: \(helloMessage)")

        //     RRD <- Handshake.RidToRrd.AuthHello -- RID
        
        let authHelloMessage = Rendezvous_Handshake.RidToRrd.AuthHello.with {
            $0.response = helloMessage.challenge
            $0.challenge = outgoingChallenge
            $0.etk = ephemeralTransportKeyPair.publicKey
        }
        
        let authHelloData = try authHelloMessage.serializedData()
        
        try await connection.send(authHelloData)
        DDLogVerbose("Send auth hello: \(authHelloMessage)")
        
        //     RRD ---- Handshake.RrdToRid.Auth ----> RID

        let authData = try await connection.receive()
        
        let authMessage = try Rendezvous_Handshake.RrdToRid.Auth(serializedData: authData)
        
        DDLogVerbose("Received auth: \(authMessage)")
        
        guard outgoingChallenge == authMessage.response else {
            throw Error.challengeMismatch
        }
        
        DDLogNotice("Handshake completed, switch to transport keys")
        let pathHash = try crypto.switchToTransportKeys(
            localEphemeralTransportKeyPair: ephemeralTransportKeyPair,
            remotePublicEphemeralTransportKey: authHelloMessage.etk
        )
        
        // TODO: Do nomination if I'm the nominator
        return pathHash
    }
}
