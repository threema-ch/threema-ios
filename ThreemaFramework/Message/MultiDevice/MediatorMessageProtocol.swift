//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

enum MediatorMessageProtocolError: Error {
    case noAbstractMessageType(for: D2d_MessageType)
}

@objc class MediatorMessageProtocol: NSObject, MediatorMessageProtocolProtocol {

    private static let MEDIATOR_COMMON_HEADER_LENGTH = 4
    private static let MEDIATOR_PAYLOAD_HEADER_LENGTH = 4
    private static let MEDIATOR_REFLECT_ID_LENGTH = 4
    private static let MEDIATOR_NONCE_LENGTH = 24
    private static let CHAT_TYPE_LENGTH = 2
    
    public enum MediatorMessageType: UInt8 {
        case proxy = 0x00
        case serverHello = 0x10
        case clientHello = 0x11
        case serverInfo = 0x12
        case reflectionQueueDry = 0x20
        case rolePromotedToLeader = 0x21
        case getDeviceInfo = 0x30
        case deviceInfo = 0x31
        case dropDevice = 0x32
        case dropDeviceAck = 0x33
        case setSharedDeviceData = 0x34
        case lock = 0x40
        case lockAck = 0x41
        case unlock = 0x42
        case unlockAck = 0x43
        case rejected = 0x44
        case ended = 0x45
        case reflect = 0x80
        case reflectAck = 0x81
        case reflected = 0x82
        case reflectedAck = 0x83
    }
    
    @objc public static let MEDIATOR_MESSAGE_TYPE_PROXY = MediatorMessageType.proxy.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_SERVER_HELLO = MediatorMessageType.serverHello.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_CLIENT_HELLO = MediatorMessageType.clientHello.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_SERVER_INFO = MediatorMessageType.serverInfo.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_REFLECTION_QUEUE_DRY = MediatorMessageType.reflectionQueueDry.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_ROLE_PROMOTED_TO_LEADER = MediatorMessageType.rolePromotedToLeader
        .rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_GET_DEVICE_INFO = MediatorMessageType.getDeviceInfo.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_DEVICE_INFO = MediatorMessageType.deviceInfo.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_DROP_DEVICE = MediatorMessageType.dropDevice.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_DROP_DEVICE_ACK = MediatorMessageType.dropDeviceAck.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_SET_SHARED_DEVICE_DATA = MediatorMessageType.setSharedDeviceData
        .rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_LOCK = MediatorMessageType.lock.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_LOCK_ACK = MediatorMessageType.lockAck.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_UNLOCK = MediatorMessageType.unlock.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_UNLOCK_ACK = MediatorMessageType.unlockAck.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_TRANSACTION_REJECT = MediatorMessageType.rejected.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_TRANSACTION_ENDED = MediatorMessageType.ended.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_REFLECT = MediatorMessageType.reflect.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_REFLECT_ACK = MediatorMessageType.reflectAck.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_REFLECTED = MediatorMessageType.reflected.rawValue
    @objc public static let MEDIATOR_MESSAGE_TYPE_REFLECTED_ACK = MediatorMessageType.reflectedAck.rawValue
    
    private static let generate_nonce_failed = "Could not generate nonce"

    private let deviceGroupPathKey: Data

    @objc init(deviceGroupPathKey: Data) {
        self.deviceGroupPathKey = deviceGroupPathKey
    }

    @objc static func doReflectMessage(_ type: Int32) -> Bool {
        let mt = getMultiDeviceMessageType(for: type)
        return mt == .deprecatedAudio || mt == .deliveryReceipt || mt == .file || mt == .deprecatedImage || mt ==
            .groupAudio || mt == .groupSetup || mt == .groupDeleteProfilePicture || mt == .groupFile || mt ==
            .groupImage || mt == .groupLeave || mt == .groupLocation || mt == .groupPollSetup || mt == .groupPollVote ||
            mt == .groupRename || mt == .groupSetProfilePicture || mt == .groupText || mt == .groupVideo || mt ==
            .location || mt == .pollSetup || mt == .pollVote || mt == .text || mt == .deprecatedVideo || mt ==
            .callOffer || mt == .callAnswer || mt == .callIceCandidate || mt == .callHangup || mt == .callRinging ||
            mt ==
            .contactSetProfilePicture || mt == .contactDeleteProfilePicture || mt == .contactRequestProfilePicture
    }
    
    static func isGroupMessage(_ type: Int32) -> Bool {
        let mt = getMultiDeviceMessageType(for: type)
        return mt == .groupAudio || mt == .groupSetup || mt == .groupDeleteProfilePicture || mt == .groupFile || mt ==
            .groupImage || mt == .groupLeave || mt == .groupLocation || mt == .groupPollSetup || mt == .groupPollVote ||
            mt == .groupRename || mt == .groupRequestSync || mt == .groupSetProfilePicture || mt == .groupText || mt ==
            .groupVideo
    }

    // MARK: Chat server protocol extension for WebSocket

    static func isMediatorMessage(_ message: Data) -> Bool {
        guard message.count >= MEDIATOR_COMMON_HEADER_LENGTH else {
            return false
        }
        
        let type = MediatorMessageProtocol.MediatorMessageType(rawValue: message[0])
        return type != .proxy && message[1] == 0x00 && message[2] == 0x00 && message[3] == 0x00
    }
    
    static func extractChatMessage(_ message: Data) -> Data {
        message.subdata(in: MEDIATOR_COMMON_HEADER_LENGTH..<message.count)
    }
    
    static func extractChatMessageAndLength(_ message: Data) -> (chatMessage: Data?, length: Int?) {
        let chatMessageWithLength = extractChatMessage(message)
        let chatMessageLength: UInt16 = chatMessageWithLength.convert()
        let chatMessage = chatMessageWithLength.subdata(in: CHAT_TYPE_LENGTH..<chatMessageWithLength.count)

        assert(chatMessageLength == chatMessage.count, "Message length mismatch")
        
        return (chatMessage, Int(chatMessageLength))
    }

    /// Add proxy common header to chat server message.
    /// - Parameter message: Chat server message
    /// - Returns: Message of type proxy
    static func addProxyCommonHeader(_ message: Data) -> Data {
        var reflectMessage = getCommonHeader(type: .proxy)
        reflectMessage.append(message)
        return reflectMessage
    }

    // MARK: Encoding multi device messages

    func encodeBeginTransactionMessage(messageType: MediatorMessageType, reason: D2d_TransactionScope.Scope) -> Data? {
        guard let encryptedTransactionScope = encryptByte(data: Data(bytes: [UInt8(reason.rawValue)], count: 1)) else {
            DDLogError("Could not encrypt transaction scope")
            return nil
        }

        var data = MediatorMessageProtocol.getCommonHeader(type: messageType)
        var beginTransactionMessage = D2m_BeginTransaction()
        beginTransactionMessage.encryptedScope = encryptedTransactionScope
        if let beginTransactionMessageData = try? beginTransactionMessage.serializedData() {
            data.append(beginTransactionMessageData)
            return data
        }
        return data
    }

    func encodeClientHello(clientHello: D2m_ClientHello) -> Data? {
        guard let clientHelloData = try? clientHello.serializedData() else {
            return nil
        }

        var clientHelloMessage = Data(
            bytes: [MediatorMessageType.clientHello.rawValue, 0x00, 0x00, 0x00],
            count: MediatorMessageProtocol.MEDIATOR_COMMON_HEADER_LENGTH
        )
        clientHelloMessage.append(clientHelloData)
        return clientHelloMessage
    }
    
    @objc static func encodeClientURLInfo(dgpkPublicKey: Data, serverGroup: UInt32) -> String? {
        // swiftformat:disable:next acronyms
        var clientURLInfo = D2m_ClientUrlInfo()
        clientURLInfo.deviceGroupID = dgpkPublicKey
        clientURLInfo.serverGroup = serverGroup

        if let clientURLInfoData = try? clientURLInfo.serializedData() {
            return clientURLInfoData.hexString.lowercased()
        }
        return nil
    }

    func encodeCommitTransactionMessage(messageType: MediatorMessageType) -> Data? {
        var data = MediatorMessageProtocol.getCommonHeader(type: messageType)
        let commitTransactionMessage = D2m_CommitTransaction()
        if let commitTransactionMessageData = try? commitTransactionMessage.serializedData() {
            data.append(commitTransactionMessageData)
            return data
        }
        return data
    }

    func encodeDevicesInfo(augmentedDeviceInfo: [UInt64: D2m_DevicesInfo.AugmentedDeviceInfo]) -> Data? {
        var data = MediatorMessageProtocol.getCommonHeader(type: .deviceInfo)
        var devicesInfo = D2m_DevicesInfo()
        devicesInfo.augmentedDeviceInfo = augmentedDeviceInfo
        if let devicesInfoData = try? devicesInfo.serializedData() {
            data.append(devicesInfoData)
            return data
        }
        return nil
    }

    func encodeDropDevice(deviceID: UInt64) -> Data? {
        var data = MediatorMessageProtocol.getCommonHeader(type: .dropDevice)
        var dropDevice = D2m_DropDevice()
        dropDevice.deviceID = deviceID
        if let dropDeviceData = try? dropDevice.serializedData() {
            data.append(dropDeviceData)
            return data
        }
        return nil
    }

    /// Encrypt and encode envelop.
    /// - Parameter envelope: Envelop encode to Mediator message
    /// - Returns: `reflectID` and `reflectMessage` as mediator message
    func encodeEnvelope(envelope: D2d_Envelope) -> (reflectID: Data?, reflectMessage: Data?) {
        guard let reflectID = NaClCrypto.shared()
            .randomBytes(Int32(MediatorMessageProtocol.MEDIATOR_REFLECT_ID_LENGTH)) else {
            DDLogError("Generate of reflect ID failed")
            return (nil, nil)
        }

        if let encryptedEnvelope = MediatorMessageProtocol.encryptEnvelope(
            envelope: envelope,
            deviceGroupPathKey: deviceGroupPathKey
        ) {
            var mediatorMsg = MediatorMessageProtocol.getCommonHeader(type: .reflect)
            mediatorMsg.append(MediatorMessageProtocol.getPayloadHeader())
            mediatorMsg.append(reflectID)
            mediatorMsg.append(encryptedEnvelope)
            return (reflectID, mediatorMsg)
        }
        return (nil, nil)
    }

    func encodeGetDeviceList() -> Data? {
        var data = MediatorMessageProtocol.getCommonHeader(type: .getDeviceInfo)
        let getDevicesInfo = D2m_GetDevicesInfo()
        if let getDevicesInfoData = try? getDevicesInfo.serializedData() {
            data.append(getDevicesInfoData)
            return data
        }
        return nil
    }

    func encodeReflectedAck(reflectID: Data) -> Data {
        var relfectedAckMessage = Data(
            bytes: [MediatorMessageType.reflectedAck.rawValue, 0x00, 0x00, 0x00],
            count: MediatorMessageProtocol.MEDIATOR_COMMON_HEADER_LENGTH
        )
        relfectedAckMessage.append(MediatorMessageProtocol.getPayloadHeader())
        relfectedAckMessage.append(reflectID)
        return relfectedAckMessage
    }

    // MARK: Decoding multi device messages

    func decodeDeviceInfo(message: Data) -> D2d_DeviceInfo? {
        try? D2d_DeviceInfo(serializedData: message)
    }

    func decodeDevicesInfo(message: Data) -> D2m_DevicesInfo? {
        try? D2m_DevicesInfo(
            serializedData: message
                .subdata(in: MediatorMessageProtocol.MEDIATOR_COMMON_HEADER_LENGTH..<message.count)
        )
    }

    func decodeDropDeviceAck(message: Data) -> D2m_DropDeviceAck? {
        try? D2m_DropDeviceAck(
            serializedData: message
                .subdata(in: MediatorMessageProtocol.MEDIATOR_COMMON_HEADER_LENGTH..<message.count)
        )
    }

    func decodeServerHello(message: Data) -> D2m_ServerHello? {
        try? D2m_ServerHello(
            serializedData: message
                .subdata(in: MediatorMessageProtocol.MEDIATOR_COMMON_HEADER_LENGTH..<message.count)
        )
    }

    func decodeServerInfo(message: Data) -> D2m_ServerInfo? {
        try? D2m_ServerInfo(
            serializedData: message
                .subdata(in: MediatorMessageProtocol.MEDIATOR_COMMON_HEADER_LENGTH..<message.count)
        )
    }

    func decodeReflectionQueueDry(message: Data) -> D2m_ReflectionQueueDry? {
        try? D2m_ReflectionQueueDry(
            serializedData: message
                .subdata(in: MediatorMessageProtocol.MEDIATOR_COMMON_HEADER_LENGTH..<message.count)
        )
    }

    func decodeRolePromotedToLeader(message: Data) -> D2m_RolePromotedToLeader? {
        try? D2m_RolePromotedToLeader(
            serializedData: message
                .subdata(in: MediatorMessageProtocol.MEDIATOR_COMMON_HEADER_LENGTH..<message.count)
        )
    }

    /// Decode mediator message type reflect ack.
    ///
    /// - Parameter message: Mediator message
    /// - Returns: Reflect ID of reflected message
    static func decodeReflectAck(_ message: Data) -> Data {
        message.subdata(in: MEDIATOR_COMMON_HEADER_LENGTH..<message.count)[4..<8]
    }

    /// Decode mediator message (type reflected).
    /// - Parameter message: Mediator message
    /// - Returns: `reflectID` and `envelopeData` encrypted envelope data of reflected message and `timestamp` mediator timestamp
    static func decodeReflected(_ message: Data) -> (reflectID: Data, envelopeData: Data, timestamp: Date) {
        let reflectedPayload = message.subdata(in: MEDIATOR_COMMON_HEADER_LENGTH..<message.count)

        let headerLenght: UInt8 = reflectedPayload.convert()

        let reflectID: Data = reflectedPayload[4..<8]
        let timestampData: Data = reflectedPayload.subdata(in: 8..<16)
        let envelopeData: Data = reflectedPayload.subdata(in: Int(headerLenght)..<reflectedPayload.count)

        let milliseconds: UInt64 = timestampData.convert(at: 0, endianess: .LittleEndian)
        let timestamp = Date(milliseconds: Int64(milliseconds))

        return (reflectID, envelopeData, timestamp)
    }

    static func decodeTransactionLocked(_ message: Data) -> D2m_TransactionRejected? {
        try? D2m_TransactionRejected(serializedData: message.subdata(in: MEDIATOR_COMMON_HEADER_LENGTH..<message.count))
    }

    static func decodeTransactionEnded(_ message: Data) -> D2m_TransactionEnded? {
        try? D2m_TransactionEnded(serializedData: message.subdata(in: MEDIATOR_COMMON_HEADER_LENGTH..<message.count))
    }

    // MARK: Encrypt / decrypt

    func encryptByte(data: Data) -> Data? {
        if let nonce = NaClCrypto.shared()?.randomBytes(Int32(MediatorMessageProtocol.MEDIATOR_NONCE_LENGTH)) {
            var encryptedMessage = Data(nonce)
            if let encryptedData = NaClCrypto.shared()?
                .symmetricEncryptData(data, withKey: deviceGroupPathKey, nonce: nonce) {
                encryptedMessage.append(encryptedData)
                return encryptedMessage
            }
            else {
                DDLogError("Could not encrypt byte")
            }
        }
        else {
            DDLogError(MediatorMessageProtocol.generate_nonce_failed)
        }
        return nil
    }
    
    func decryptByte(data: Data) -> Data? {
        if data.count >= MediatorMessageProtocol.MEDIATOR_NONCE_LENGTH {
            let nonce = data[0..<MediatorMessageProtocol.MEDIATOR_NONCE_LENGTH]
            if let decryptedData = NaClCrypto.shared()?.symmetricDecryptData(
                data[MediatorMessageProtocol.MEDIATOR_NONCE_LENGTH..<data.count],
                withKey: deviceGroupPathKey,
                nonce: nonce
            ) {
                return decryptedData
            }
            else {
                DDLogError("Could not decrypt envelope")
            }
        }
        else {
            DDLogError("Could not extract nonce, message too short")
        }
        return nil
    }

    // MARK: Create multi device envelope message
    
    /// Create Envelope for contact sync.
    /// - Parameter contact: Contact for sync
    /// - Returns: Envelope with contact sync
    func getEnvelopeForContactSync(contact: Sync_Contact) -> D2d_Envelope {
        var sContactSync = D2d_ContactSync()
        sContactSync.set.contact = contact

        var envelope = D2d_Envelope()
        envelope.contactSync = sContactSync

        return envelope
    }
    
    func getEnvelopeForContactSyncDelete(identity: String) -> D2d_Envelope {
        var sContactSync = D2d_ContactSync()
        sContactSync.delete.deleteIdentity = identity

        var envelope = D2d_Envelope()
        envelope.contactSync = sContactSync

        return envelope
    }

    /// Create Envelope for incoming message.
    /// - Parameter type: Message type, see MSGTYPE_... in `ProtocolDefinitions.h`
    /// - Parameter body: Message data
    /// - Parameter messageID: ID of the message
    /// - Parameter senderIdentity: Sender of the message
    /// - Parameter createdAt: Message date
    /// - Returns: Envelope with incoming message
    func getEnvelopeForIncomingMessage(
        type: Int32,
        body: Data?,
        messageID: UInt64,
        senderIdentity: String,
        createdAt: Date
    ) -> D2d_Envelope {
        var incomigMessage = D2d_IncomingMessage()
        incomigMessage.type = MediatorMessageProtocol.getMultiDeviceMessageType(for: type)
        if let body = body {
            incomigMessage.body = body
        }
        incomigMessage.messageID = messageID
        incomigMessage.senderIdentity = senderIdentity
        incomigMessage.createdAt = UInt64(createdAt.millisecondsSince1970)

        var envelope = D2d_Envelope()
        envelope.padding = BytesUtility.paddingRandom()
        envelope.incomingMessage = incomigMessage

        return envelope
    }
    
    /// Create Envelope for outgoing message.
    /// - Parameter type: Message type, see MSGTYPE_... in `ProtocolDefinitions.h`
    /// - Parameter body: Message data
    /// - Parameter messageID: ID of the message
    /// - Parameter receiverIdentity: Receiver of the message
    /// - Parameter createdAt: Message date
    /// - Returns: Envelope with outgoing message
    func getEnvelopeForOutgoingMessage(
        type: Int32,
        body: Data?,
        messageID: UInt64,
        receiverIdentity: String,
        createdAt: Date
    ) -> D2d_Envelope {
        var receiver = D2d_MessageReceiver()
        receiver.identity = receiverIdentity
        
        return getEnvelopeForOutgoingMessage(type, body, messageID, receiver, createdAt)
    }
    
    /// Create Envelope for outgoing message.
    /// - Parameter type: Message type, see MSGTYPE_... in `ProtocolDefinitions.h`
    /// - Parameter body: Message data
    /// - Parameter messageID: ID of the message
    /// - Parameter groupID: Group ID of message
    /// - Parameter groupCreatorIdentity: Group ID of message
    /// - Parameter createdAt: Message date
    /// - Returns: Envelope with outgoing group message
    func getEnvelopeForOutgoingMessage(
        type: Int32,
        body: Data?,
        messageID: UInt64,
        groupID: UInt64,
        groupCreatorIdentity: String,
        createdAt: Date
    ) -> D2d_Envelope {
        var group = Common_GroupIdentity()
        group.groupID = groupID
        group.creatorIdentity = groupCreatorIdentity

        var receiver = D2d_MessageReceiver()
        receiver.group = group

        return getEnvelopeForOutgoingMessage(type, body, messageID, receiver, createdAt)
    }
    
    private func getEnvelopeForOutgoingMessage(
        _ type: Int32,
        _ body: Data?,
        _ messageID: UInt64,
        _ receiver: D2d_MessageReceiver,
        _ createdAt: Date
    ) -> D2d_Envelope {
        var outgoingMessage = D2d_OutgoingMessage()
        outgoingMessage.type = MediatorMessageProtocol.getMultiDeviceMessageType(for: type)
        if let body = body {
            outgoingMessage.body = body
        }
        outgoingMessage.messageID = messageID
        
        outgoingMessage.receiver = receiver
        outgoingMessage.createdAt = UInt64(createdAt.millisecondsSince1970)

        var envelope = D2d_Envelope()
        envelope.padding = BytesUtility.paddingRandom()
        envelope.outgoingMessage = outgoingMessage

        return envelope
    }

    func getEnvelopeForOutgoingMessageSent(messageID: Data, receiver: D2d_MessageReceiver) -> D2d_Envelope {
        var outgoingMessageSent = D2d_OutgoingMessageSent()
        outgoingMessageSent.messageID = messageID.convert()
        outgoingMessageSent.receiver = receiver

        var envelope = D2d_Envelope()
        envelope.padding = BytesUtility.paddingRandom()
        envelope.outgoingMessageSent = outgoingMessageSent

        return envelope
    }

    func getEnvelopeForProfileUpdate(userProfile: Sync_UserProfile) -> D2d_Envelope {
        var userProfileSync = D2d_UserProfileSync()
        userProfileSync.set.userProfile = userProfile

        var envelope = D2d_Envelope()
        envelope.userProfileSync = userProfileSync

        return envelope
    }

    func getEnvelopeForSettingsUpdate(settings: Sync_Settings) -> D2d_Envelope {
        var settingsSync = D2d_SettingsSync()
        settingsSync.set.settings = settings

        var envelope = D2d_Envelope()
        envelope.settingsSync = settingsSync

        return envelope
    }

    // MARK: Encrypt / decrypt envelop

    /// Decrypt message and decode envelope.
    ///
    /// - Parameter data: Encrypted message
    /// - Parameter deviceGroupPathKey: Key for message decryption
    ///
    /// - Returns: Decrypted and decoded envelope
    static func decryptEnvelope(data: Data, deviceGroupPathKey: Data) -> D2d_Envelope? {
        do {
            if data.count >= MEDIATOR_NONCE_LENGTH {
                let nonce = data[0..<MEDIATOR_NONCE_LENGTH]
                if let decryptedData = NaClCrypto.shared()?
                    .symmetricDecryptData(
                        data[MEDIATOR_NONCE_LENGTH..<data.count],
                        withKey: deviceGroupPathKey,
                        nonce: nonce
                    ) {
                    return try D2d_Envelope(serializedData: decryptedData)
                }
                else {
                    DDLogError("Could not decrypt envelope")
                }
            }
            else {
                DDLogError("Could not extract nonce, message too short")
            }
        }
        catch {
            DDLogError(String(format: "Could not deserialize envelope: %@", error.localizedDescription))
        }
        
        return nil
    }

    /// Encode and encrypt envelope.
    ///
    /// - Parameter envelope: Plain data
    /// - Parameter deviceGroupPathKey: Key for message decryption
    ///
    /// - Returns: Encoded and encrypted data
    static func encryptEnvelope(envelope: D2d_Envelope, deviceGroupPathKey: Data) -> Data? {
        do {
            let envelopeData = try envelope.serializedData()
            if let nonce = NaClCrypto.shared()?.randomBytes(Int32(MEDIATOR_NONCE_LENGTH)) {
                var encryptedMessage = Data(nonce)
                if let encryptedData = NaClCrypto.shared()?
                    .symmetricEncryptData(envelopeData, withKey: deviceGroupPathKey, nonce: nonce) {
                    encryptedMessage.append(encryptedData)
                    return encryptedMessage
                }
                else {
                    DDLogError("Cloud not encrypt envelope")
                }
            }
            else {
                DDLogError(generate_nonce_failed)
            }
        }
        catch {
            DDLogError(String(format: "Could not serialize envelope: %@", error.localizedDescription))
        }
        
        return nil
    }

    // MARK: Misc
    
    static func getAbstractMessageType(for type: D2d_MessageType) throws -> Int32 {
        switch type {
        case .deprecatedAudio:
            return MSGTYPE_AUDIO
        case .pollSetup:
            return MSGTYPE_BALLOT_CREATE
        case .pollVote:
            return MSGTYPE_BALLOT_VOTE
        case .deliveryReceipt:
            return MSGTYPE_DELIVERY_RECEIPT
        case .file:
            return MSGTYPE_FILE
        case .groupAudio:
            return MSGTYPE_GROUP_AUDIO
        case .groupPollSetup:
            return MSGTYPE_GROUP_BALLOT_CREATE
        case .groupPollVote:
            return MSGTYPE_GROUP_BALLOT_VOTE
        case .groupSetup:
            return MSGTYPE_GROUP_CREATE
        case .groupDeleteProfilePicture:
            return MSGTYPE_GROUP_DELETE_PHOTO
        case .groupFile:
            return MSGTYPE_GROUP_FILE
        case .groupImage:
            return MSGTYPE_GROUP_IMAGE
        case .groupLeave:
            return MSGTYPE_GROUP_LEAVE
        case .groupLocation:
            return MSGTYPE_GROUP_LOCATION
        case .groupRename:
            return MSGTYPE_GROUP_RENAME
        case .groupRequestSync:
            return MSGTYPE_GROUP_REQUEST_SYNC
        case .groupSetProfilePicture:
            return MSGTYPE_GROUP_SET_PHOTO
        case .groupText:
            return MSGTYPE_GROUP_TEXT
        case .groupVideo:
            return MSGTYPE_GROUP_VIDEO
        case .deprecatedImage:
            return MSGTYPE_IMAGE
        case .location:
            return MSGTYPE_LOCATION
        case .text:
            return MSGTYPE_TEXT
        case .deprecatedVideo:
            return MSGTYPE_VIDEO
        case .callOffer:
            return MSGTYPE_VOIP_CALL_OFFER
        case .callAnswer:
            return MSGTYPE_VOIP_CALL_ANSWER
        case .callIceCandidate:
            return MSGTYPE_VOIP_CALL_ICECANDIDATE
        case .callHangup:
            return MSGTYPE_VOIP_CALL_HANGUP
        case .callRinging:
            return MSGTYPE_VOIP_CALL_RINGING
        case .contactSetProfilePicture:
            return MSGTYPE_CONTACT_SET_PHOTO
        case .contactDeleteProfilePicture:
            return MSGTYPE_CONTACT_DELETE_PHOTO
        case .contactRequestProfilePicture:
            return MSGTYPE_CONTACT_REQUEST_PHOTO
        case .typingIndicator:
            return MSGTYPE_TYPING_INDICATOR
        case .invalid:
            throw MediatorMessageProtocolError.noAbstractMessageType(for: .invalid)
        default:
            throw MediatorMessageProtocolError.noAbstractMessageType(for: type)
        }
    }

    static func getMultiDeviceMessageType(for type: Int32) -> D2d_MessageType {
        switch type {
        case MSGTYPE_AUDIO:
            return .deprecatedAudio
        case MSGTYPE_BALLOT_CREATE:
            return .pollSetup
        case MSGTYPE_BALLOT_VOTE:
            return .pollVote
        case MSGTYPE_DELIVERY_RECEIPT:
            return .deliveryReceipt
        case MSGTYPE_FILE:
            return .file
        case MSGTYPE_GROUP_AUDIO:
            return .groupAudio
        case MSGTYPE_GROUP_BALLOT_CREATE:
            return .groupPollSetup
        case MSGTYPE_GROUP_BALLOT_VOTE:
            return .groupPollVote
        case MSGTYPE_GROUP_CREATE:
            return .groupSetup
        case MSGTYPE_GROUP_DELETE_PHOTO:
            return .groupDeleteProfilePicture
        case MSGTYPE_GROUP_FILE:
            return .groupFile
        case MSGTYPE_GROUP_IMAGE:
            return .groupImage
        case MSGTYPE_GROUP_LEAVE:
            return .groupLeave
        case MSGTYPE_GROUP_LOCATION:
            return .groupLocation
        case MSGTYPE_GROUP_RENAME:
            return .groupRename
        case MSGTYPE_GROUP_REQUEST_SYNC:
            return .groupRequestSync
        case MSGTYPE_GROUP_SET_PHOTO:
            return .groupSetProfilePicture
        case MSGTYPE_GROUP_TEXT:
            return .groupText
        case MSGTYPE_GROUP_VIDEO:
            return .groupVideo
        case MSGTYPE_IMAGE:
            return .deprecatedImage
        case MSGTYPE_LOCATION:
            return .location
        case MSGTYPE_TEXT:
            return .text
        case MSGTYPE_VIDEO:
            return .deprecatedVideo
        case MSGTYPE_VOIP_CALL_OFFER:
            return .callOffer
        case MSGTYPE_VOIP_CALL_ANSWER:
            return .callAnswer
        case MSGTYPE_VOIP_CALL_ICECANDIDATE:
            return .callIceCandidate
        case MSGTYPE_VOIP_CALL_HANGUP:
            return .callHangup
        case MSGTYPE_VOIP_CALL_RINGING:
            return .callRinging
        case MSGTYPE_CONTACT_SET_PHOTO:
            return .contactSetProfilePicture
        case MSGTYPE_CONTACT_DELETE_PHOTO:
            return .contactDeleteProfilePicture
        case MSGTYPE_CONTACT_REQUEST_PHOTO:
            return .contactRequestProfilePicture
        case MSGTYPE_TYPING_INDICATOR:
            return .typingIndicator
        default:
            return .invalid
        }
    }

    /// Get message type as string for logging description.
    /// - Parameter type: Message type
    /// - SeeAlso: `AbstractMessage`, `ProtocolDefines.h`
    /// - Returns: Message type as string (multi device naming)
    @objc static func getTypeDescription(type: Int32) -> String {
        "\(getMultiDeviceMessageType(for: type))"
    }

    private static func getCommonHeader(type: MediatorMessageType) -> Data {
        Data(BytesUtility.padding([type.rawValue], pad: 0x00, length: MEDIATOR_COMMON_HEADER_LENGTH))
    }
    
    private static func getPayloadHeader() -> Data {
        Data(BytesUtility.padding([0x08], pad: 0x00, length: MEDIATOR_PAYLOAD_HEADER_LENGTH))
    }
}

extension Date {
    var millisecondsSince1970: Int64 {
        Int64((timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}

protocol D2d_LoggingDescriptionProtocol {
    var loggingDescription: String { get }
}

// MARK: - D2d_Envelope + D2d_LoggingDescriptionProtocol

extension D2d_Envelope: D2d_LoggingDescriptionProtocol {
    var loggingDescription: String {
        switch content {
        case let .contactSync(msg):
            return msg.loggingDescription
        case let .distributionListSync(msg):
            return msg.loggingDescription
        case let .groupSync(msg):
            return msg.loggingDescription
        case let .incomingMessage(msg):
            return msg.loggingDescription
        case let .outgoingMessage(msg):
            return msg.loggingDescription
        case let .outgoingMessageSent(msg):
            return msg.loggingDescription
        case let .settingsSync(msg):
            return msg.loggingDescription
        case let .userProfileSync(msg):
            return msg.loggingDescription
        default:
            return "(unknown multi device message type)"
        }
    }
}

// MARK: - D2d_ContactSync + D2d_LoggingDescriptionProtocol

extension D2d_ContactSync: D2d_LoggingDescriptionProtocol {
    var loggingDescription: String {
        "(type: \(D2d_ContactSync.self))"
    }
}

// MARK: - D2d_DistributionListSync + D2d_LoggingDescriptionProtocol

extension D2d_DistributionListSync: D2d_LoggingDescriptionProtocol {
    var loggingDescription: String {
        "(type: \(D2d_DistributionListSync.self))"
    }
}

// MARK: - D2d_GroupSync + D2d_LoggingDescriptionProtocol

extension D2d_GroupSync: D2d_LoggingDescriptionProtocol {
    var loggingDescription: String {
        "(type: \(D2d_GroupSync.self))"
    }
}

// MARK: - D2d_IncomingMessage + D2d_LoggingDescriptionProtocol

extension D2d_IncomingMessage: D2d_LoggingDescriptionProtocol {
    var loggingDescription: String {
        "(type: \(type); id: \(NSData.convertBytes(messageID).hexString))"
    }
}

// MARK: - D2d_OutgoingMessage + D2d_LoggingDescriptionProtocol

extension D2d_OutgoingMessage: D2d_LoggingDescriptionProtocol {
    var loggingDescription: String {
        "(type: \(type); id: \(NSData.convertBytes(messageID).hexString))"
    }
}

// MARK: - D2d_OutgoingMessageSent + D2d_LoggingDescriptionProtocol

extension D2d_OutgoingMessageSent: D2d_LoggingDescriptionProtocol {
    var loggingDescription: String {
        "(type: \(D2d_OutgoingMessageSent.self); id: \(NSData.convertBytes(messageID).hexString))"
    }
}

// MARK: - D2d_SettingsSync + D2d_LoggingDescriptionProtocol

extension D2d_SettingsSync: D2d_LoggingDescriptionProtocol {
    var loggingDescription: String {
        "(type: \(D2d_SettingsSync.self))"
    }
}

// MARK: - D2d_UserProfileSync + D2d_LoggingDescriptionProtocol

extension D2d_UserProfileSync: D2d_LoggingDescriptionProtocol {
    var loggingDescription: String {
        "(type: \(D2d_UserProfileSync.self))"
    }
}
