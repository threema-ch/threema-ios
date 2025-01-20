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

protocol MediatorMessageProtocolProtocol {

    func encodeBeginTransactionMessage(
        messageType: MediatorMessageProtocol.MediatorMessageType,
        reason: D2d_TransactionScope.Scope
    ) -> Data?

    func encodeClientHello(clientHello: D2m_ClientHello) -> Data?

    func encodeCommitTransactionMessage(messageType: MediatorMessageProtocol.MediatorMessageType) -> Data?

    func encodeDevicesInfo(augmentedDeviceInfo: [UInt64: D2m_DevicesInfo.AugmentedDeviceInfo]) -> Data?

    func encodeDropDevice(deviceID: UInt64) -> Data?

    func encodeEnvelope(envelope: D2d_Envelope) -> (reflectID: Data?, reflectMessage: Data?)

    func encodeGetDeviceList() -> Data?

    func encodeReflectedAck(reflectID: Data) -> Data

    func decodeDeviceInfo(message: Data) -> D2d_DeviceInfo?

    func decodeDevicesInfo(message: Data) -> D2m_DevicesInfo?

    func decodeDropDeviceAck(message: Data) -> D2m_DropDeviceAck?

    func decodeServerHello(message: Data) -> D2m_ServerHello?

    func decodeServerInfo(message: Data) -> D2m_ServerInfo?

    func decodeReflectionQueueDry(message: Data) -> D2m_ReflectionQueueDry?

    func decodeRolePromotedToLeader(message: Data) -> D2m_RolePromotedToLeader?

    func encryptByte(data: Data, key: Data) -> Data?

    func decryptByte(data: Data, key: Data) -> Data?

    func getEnvelopeForContactSync(contact: Sync_Contact, syncAction: DeltaSyncContact.SyncAction) -> D2d_Envelope

    func getEnvelopeForGroupSync(group: Sync_Group, syncAction: D2d_GroupSync.OneOf_Action) -> D2d_Envelope

    func getEnvelopeForIncomingMessage(
        type: Int32,
        body: Data?,
        messageID: UInt64,
        senderIdentity: String,
        createdAt: Date,
        nonce: Data
    ) -> D2d_Envelope

    // swiftformat:disable:next all
    func getEnvelopeForIncomingMessageUpdate(messageIDs: [Data], messageReadDates: [Date?], conversationID: D2d_ConversationId)
        -> D2d_Envelope

    func getEnvelopeForOutgoingMessage(
        type: Int32,
        body: Data?,
        messageID: UInt64,
        receiverIdentity: String,
        createdAt: Date,
        nonce: Data,
        deviceID: UInt64
    ) -> D2d_Envelope

    func getEnvelopeForOutgoingMessage(
        type: Int32,
        body: Data?,
        messageID: UInt64,
        groupID: UInt64,
        groupCreatorIdentity: String,
        createdAt: Date,
        nonces: [Data],
        deviceID: UInt64
    ) -> D2d_Envelope

    // swiftformat:disable:next all
    func getEnvelopeForOutgoingMessageUpdate(messageID: Data, conversationID: D2d_ConversationId, deviceID: UInt64) -> D2d_Envelope

    func getEnvelopeForProfileUpdate(userProfile: Sync_UserProfile) -> D2d_Envelope

    func getEnvelopeForSettingsUpdate(settings: Sync_Settings) -> D2d_Envelope

    func getEnvelopeForMdmParametersUpdate(mdmParameters: Sync_MdmParameters) -> D2d_Envelope

    func decryptEnvelope(data: Data) -> D2d_Envelope?

    func encryptEnvelope(envelope: D2d_Envelope) -> Data?
}
