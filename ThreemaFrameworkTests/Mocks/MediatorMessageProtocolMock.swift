//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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
import ThreemaProtocols
@testable import ThreemaFramework

class MediatorMessageProtocolMock: MediatorMessageProtocolProtocol {
    private let deviceGroupKeys: DeviceGroupKeys
    private let mmp: MediatorMessageProtocolProtocol

    struct ReflectData {
        let id: Data
        let message: Data
    }

    private var returnValues: [ReflectData]

    init(deviceGroupKeys: DeviceGroupKeys, returnValues: [ReflectData]) {
        self.deviceGroupKeys = deviceGroupKeys
        self.returnValues = returnValues

        self.mmp = MediatorMessageProtocol(deviceGroupKeys: deviceGroupKeys)
    }

    convenience init() {
        self.init(
            deviceGroupKeys: MockData.deviceGroupKeys,
            returnValues: []
        )
    }

    private func nextReturnValue(for reflectID: Data? = nil) -> (reflectID: Data?, reflectMessage: Data?) {
        guard let reflectID else {
            guard let reflectData = returnValues.first else {
                return (nil, nil)
            }
            returnValues.remove(at: 0)
            return (reflectData.id, reflectData.message)
        }

        guard let reflectData = returnValues.first(where: { $0.id == reflectID }) else {
            return (nil, nil)
        }
        return (reflectData.id, reflectData.message)
    }

    func encodeClientHello(clientHello: D2m_ClientHello) -> Data? {
        nil
    }

    func encodeBeginTransactionMessage(
        messageType: MediatorMessageProtocol.MediatorMessageType,
        reason: D2d_TransactionScope.Scope
    ) -> Data? {
        mmp.encodeBeginTransactionMessage(messageType: messageType, reason: reason)
    }

    func encodeCommitTransactionMessage(messageType: MediatorMessageProtocol.MediatorMessageType) -> Data? {
        mmp.encodeCommitTransactionMessage(messageType: messageType)
    }

    func encodeDropDevice(deviceID: UInt64) -> Data? {
        nil
    }

    func encodeDevicesInfo(augmentedDeviceInfo: [UInt64: D2m_DevicesInfo.AugmentedDeviceInfo]) -> Data? {
        nil
    }

    func encodeEnvelope(envelope: D2d_Envelope) -> (reflectID: Data?, reflectMessage: Data?) {
        nextReturnValue()
    }

    func encodeGetDeviceList() -> Data? {
        nil
    }

    func encodeReflectedAck(reflectID: Data) -> Data {
        nextReturnValue(for: reflectID).reflectMessage!
    }

    func decodeDeviceInfo(message: Data) -> D2d_DeviceInfo? {
        nil
    }

    func decodeDevicesInfo(message: Data) -> D2m_DevicesInfo? {
        nil
    }

    func decodeDropDeviceAck(message: Data) -> D2m_DropDeviceAck? {
        nil
    }

    func decodeServerHello(message: Data) -> D2m_ServerHello? {
        nil
    }

    func decodeServerInfo(message: Data) -> D2m_ServerInfo? {
        nil
    }

    func decodeReflectionQueueDry(message: Data) -> D2m_ReflectionQueueDry? {
        nil
    }

    func decodeRolePromotedToLeader(message: Data) -> D2m_RolePromotedToLeader? {
        nil
    }

    func encryptByte(data: Data, key: Data) -> Data? {
        nil
    }

    func decryptByte(data: Data, key: Data) -> Data? {
        nil
    }

    func getEnvelopeForIncomingMessage(
        type: Int32,
        body: Data?,
        messageID: UInt64,
        senderIdentity: String,
        createdAt: Date,
        nonce: Data
    ) -> D2d_Envelope {
        D2d_Envelope()
    }

    func getEnvelopeForIncomingMessageUpdate(
        messageIDs: [Data],
        messageReadDates: [Date?],
        // swiftformat:disable:next all
        conversationID: D2d_ConversationId
    ) -> D2d_Envelope {
        D2d_Envelope()
    }

    func getEnvelopeForOutgoingMessage(
        type: Int32,
        body: Data?,
        messageID: UInt64,
        groupID: UInt64,
        groupCreatorIdentity: String,
        createdAt: Date,
        nonces: [Data],
        deviceID: UInt64
    ) -> D2d_Envelope {
        D2d_Envelope()
    }

    func getEnvelopeForOutgoingMessage(
        type: Int32,
        body: Data?,
        messageID: UInt64,
        receiverIdentity: String,
        createdAt: Date,
        nonce: Data,
        deviceID: UInt64
    ) -> D2d_Envelope {
        mmp.getEnvelopeForOutgoingMessage(
            type: type,
            body: body,
            messageID: messageID,
            receiverIdentity: receiverIdentity,
            createdAt: createdAt,
            nonce: nonce,
            deviceID: deviceID
        )
    }

    // swiftformat:disable:next all
    func getEnvelopeForOutgoingMessageUpdate(messageID: Data, conversationID: D2d_ConversationId, deviceID: UInt64) -> D2d_Envelope {
        D2d_Envelope()
    }

    func getEnvelopeForProfileUpdate(userProfile: Sync_UserProfile) -> D2d_Envelope {
        D2d_Envelope()
    }

    func getEnvelopeForContactSync(contact: Sync_Contact, syncAction: DeltaSyncContact.SyncAction) -> D2d_Envelope {
        D2d_Envelope()
    }

    func getEnvelopeForContactSyncDelete(identity: String) -> D2d_Envelope {
        D2d_Envelope()
    }

    func getEnvelopeForGroupSync(group: Sync_Group, syncAction: D2d_GroupSync.OneOf_Action) -> D2d_Envelope {
        D2d_Envelope()
    }

    func getEnvelopeForSettingsUpdate(settings: Sync_Settings) -> D2d_Envelope {
        D2d_Envelope()
    }

    func getEnvelopeForMdmParametersUpdate(mdmParameters: Sync_MdmParameters) -> D2d_Envelope {
        D2d_Envelope()
    }

    func decryptEnvelope(data: Data) -> D2d_Envelope? {
        try? D2d_Envelope(serializedData: data)
    }

    func encryptEnvelope(envelope: D2d_Envelope) -> Data? {
        nil
    }
}
