//! Payloads exchanged during the post-handshake state.
use std::collections::HashMap;

use educe::Educe;
use libthreema_macros::{DebugVariantNames, Name, VariantNames};

use crate::{
    common::D2xDeviceId,
    d2m::{
        D2mProtocolError, D2mProtocolInternalEncodingErrorCause, D2mProtocolInternalErrorCause,
        payload::{PayloadDecoder, PayloadEncoder, ReflectFlags},
    },
    protobuf,
    utils::{
        bytes::{ByteReader as _, ByteWriter, OwnedVecByteReader},
        debug::{Name as _, debug_slice_length},
        time::Duration,
    },
};

#[derive(Clone, Copy, strum::FromRepr, VariantNames, DebugVariantNames)]
#[repr(u8)]
enum IncomingPayloadType {
    // Chat server proxying
    Proxy = 0x00,

    // States
    ReflectionQueueDry = 0x20,
    RolePromotedToLeader = 0x21,

    // Device management
    DevicesInfo = 0x31,
    DropDeviceAck = 0x33,

    // Transactions
    BeginTransactionAck = 0x41,
    CommitTransactionAck = 0x43,
    TransactionRejected = 0x44,
    TransactionEnded = 0x45,

    // Reflection
    ReflectAck = 0x81,
    Reflected = 0x82,
}

/// Acknowledges that a message to be reflected to all other devices has been stored in their respective
/// reflection queues.
#[derive(Debug, Name)]
pub struct ReflectAck {
    /// Refers to the `Reflect ID` as sent in the `Reflect` message.
    pub reflect_id: u32,

    /// Unix-ish timestamp in milliseconds when the message has been stored in the reflection queue of the
    /// mediator server.
    pub timestamp: u64,
}
impl ReflectAck {
    fn decode(mut reader: OwnedVecByteReader) -> Result<Self, D2mProtocolError> {
        reader
            .run(|reader| {
                // Skip reserved bytes
                reader.skip(4)?;

                // Decode reflect-id and timestamp
                let reflect_id = reader.read_u32_le()?;
                let timestamp = reader.read_u64_le()?;

                // Note: Intentionally **not** calling `reader.expect_consumed()` since we may extend the
                // struct in a backwards-compatible way.

                Ok(Self {
                    reflect_id,
                    timestamp,
                })
            })
            .map_err(|error| D2mProtocolError::DecodingFailed {
                name: Self::NAME,
                source: error.into(),
            })
    }
}

/// A message from the device's reflection queue.
#[derive(Name, Educe)]
#[educe(Debug)]
pub struct Reflected {
    /// Flags set for the message. See [`ReflectFlags`] for known values.
    pub flags: ReflectFlags,

    /// Monotonically increasing unique number (per device slot) used for acknowledgement. May wrap.
    pub reflect_id: u32,

    /// Unix-ish timestamp in milliseconds when the message has been stored in the reflection queue of the
    /// mediator server.
    pub timestamp: u64,

    /// The protobuf-encoded and encrypted data to be reflected, encrypted by `DGRK.secret` and prefixed with
    /// a random nonce.
    #[educe(Debug(method(debug_slice_length)))]
    pub envelope: Vec<u8>,
}
impl Reflected {
    const MIN_HEADER_LENGTH: u8 = 16;

    fn decode(mut reader: OwnedVecByteReader) -> Result<Self, D2mProtocolError> {
        // Decode header length
        //
        // Note: Checking the minimum header length is necessary as we might otherwise read garbage header
        // data from the envelope that's behind it.
        let header_length = reader
            .read_u8()
            .map_err(|error| D2mProtocolError::DecodingFailed {
                name: Self::NAME,
                source: error.into(),
            })?;
        if header_length < Self::MIN_HEADER_LENGTH {
            return Err(D2mProtocolError::InvalidMessage {
                name: Self::NAME,
                cause: format!(
                    "Header needs to be at least {min_length} bytes but got {header_length}",
                    min_length = Self::MIN_HEADER_LENGTH
                ),
            });
        }

        // Decode known header fields
        let (flags, reflect_id, timestamp) = reader
            .run_at(0, |mut reader| {
                // Skip reserved byte
                reader.skip(1)?;

                // Decode flags, reflected-id and timestamp
                let flags = reader.read_u16_le()?;
                let reflect_id = reader.read_u32_le()?;
                let timestamp = reader.read_u64_le()?;

                Ok((flags, reflect_id, timestamp))
            })
            .map_err(|error| D2mProtocolError::DecodingFailed {
                name: Self::NAME,
                source: error.into(),
            })?;

        // Move beyond the header and extract the envelope
        let envelope = reader
            .run_owned(|mut reader| {
                reader.skip(header_length as usize)?;
                Ok(reader.read_remaining_owned())
            })
            .map_err(|error| D2mProtocolError::DecodingFailed {
                name: Self::NAME,
                source: error.into(),
            })?;

        Ok(Self {
            reflect_id,
            timestamp,
            flags: ReflectFlags(flags),
            envelope,
        })
    }
}

/// Augmented device information.
#[derive(Educe)]
#[educe(Debug)]
pub struct AugmentedDeviceInfo {
    /// Device info (`d2d.DeviceInfo`), encrypted by `DGDIK.secret` and prefixed with a random nonce.
    #[educe(Debug(method(debug_slice_length)))]
    pub encrypted_device_info: Vec<u8>,

    /// Expiration policy of the device.
    pub device_slot_expiration_policy: Option<protobuf::d2m::DeviceSlotExpirationPolicy>,

    /// Connection state of the device.
    pub connection_state: Option<protobuf::d2m::devices_info::augmented_device_info::ConnectionState>,
}
impl From<protobuf::d2m::devices_info::AugmentedDeviceInfo> for AugmentedDeviceInfo {
    fn from(
        protobuf::d2m::devices_info::AugmentedDeviceInfo {
            encrypted_device_info,
            device_slot_expiration_policy,
            connection_state,
        }: protobuf::d2m::devices_info::AugmentedDeviceInfo,
    ) -> Self {
        Self {
            encrypted_device_info,
            device_slot_expiration_policy: protobuf::d2m::DeviceSlotExpirationPolicy::try_from(
                device_slot_expiration_policy,
            )
            .ok(),
            connection_state,
        }
    }
}

/// Device information of all devices.
#[derive(Debug)]
pub struct DevicesInfo(pub HashMap<D2xDeviceId, AugmentedDeviceInfo>);
impl From<protobuf::d2m::DevicesInfo> for DevicesInfo {
    fn from(
        protobuf::d2m::DevicesInfo {
            augmented_device_info,
        }: protobuf::d2m::DevicesInfo,
    ) -> Self {
        Self(
            augmented_device_info
                .into_iter()
                .map(|(id, info)| (D2xDeviceId(id), AugmentedDeviceInfo::from(info)))
                .collect(),
        )
    }
}

/// A begin transaction request has been rejected because another transaction is already in process.
#[derive(Educe)]
#[educe(Debug)]
pub struct TransactionRejected {
    /// The device that currently holds the lock.
    pub device_id: D2xDeviceId,

    /// The encrypted transaction scope (`d2d.TransactionScope`) associated with the currently locked
    /// transaction, encrypted by `DGTSK.secret` and prefixed with a random nonce.
    #[educe(Debug(method(debug_slice_length)))]
    pub encrypted_scope: Vec<u8>,
}
impl From<protobuf::d2m::TransactionRejected> for TransactionRejected {
    fn from(
        protobuf::d2m::TransactionRejected {
            device_id,
            encrypted_scope,
        }: protobuf::d2m::TransactionRejected,
    ) -> Self {
        Self {
            device_id: D2xDeviceId(device_id),
            encrypted_scope,
        }
    }
}

/// When a transaction ends (either because it was committed or because the device disconnected), this message
/// is sent to all connected devices except for the device that committed the transaction.
///
/// This can be used by the other devices as a _retry signal_ if a previous `BeginTransaction` attempt was
/// unsuccessful.
#[derive(Educe)]
#[educe(Debug)]
pub struct TransactionEnded {
    /// The device that held the lock up until now.
    pub device_id: D2xDeviceId,

    /// The encrypted transaction scope (`d2d.TransactionScope`) associated with the transaction that just
    /// ended, encrypted by `DGTSK.secret` and prefixed with a random nonce.
    #[educe(Debug(method(debug_slice_length)))]
    pub encrypted_scope: Vec<u8>,
}
impl From<protobuf::d2m::TransactionEnded> for TransactionEnded {
    fn from(
        protobuf::d2m::TransactionEnded {
            device_id,
            encrypted_scope,
        }: protobuf::d2m::TransactionEnded,
    ) -> Self {
        Self {
            device_id: D2xDeviceId(device_id),
            encrypted_scope,
        }
    }
}

/// An incoming payload received from the mediator server during the post-handshake phase.
#[derive(Debug, Name, VariantNames)]
pub enum IncomingPayload {
    /// Proxied message from the chat server.
    Proxy(Vec<u8>),

    /// Indicates that the device's reflection queue on the server has been fully transmitted to the device.
    ReflectionQueueDry,

    /// The device's role has been promoted to leader, indicating that the device should now request to
    /// receive and reflect messages from the chat server.
    RolePromotedToLeader,

    /// Device information of all devices.
    DevicesInfo(DevicesInfo),

    /// Acknowledges that a device has been dropped and the device slot has been free'd.
    DropDeviceAck(D2xDeviceId),

    /// Acknowledges that the device group lock has been acquired and that the transaction has been started.
    BeginTransactionAck,

    /// Commits a transaction, releases a device group lock.
    CommitTransactionAck,

    /// A begin transaction request has been rejected because another transaction is already in process.
    TransactionRejected(TransactionRejected),

    /// Another device just ended a transaction, releasing the device group lock.
    TransactionEnded(TransactionEnded),

    /// Acknowledges that a message to be reflected to all other devices has been stored in their respective
    /// reflection queues.
    ReflectAck(ReflectAck),

    /// A message from the device's reflection queue.
    Reflected(Reflected),

    /// The payload type is not known, either due to server misbehavior or as consequence of running an old
    /// version of libthreema. This information might be helpful for debugging.
    UnknownPayload {
        /// The (unsupported) type of the payload.
        payload_type: u8,

        /// The length of the payload.
        length: usize,
    },
}
impl PayloadDecoder for IncomingPayload {
    fn decode(r#type: u8, reader: OwnedVecByteReader) -> Result<Self, D2mProtocolError> {
        // Parse payload type
        let Some(r#type) = IncomingPayloadType::from_repr(r#type) else {
            return Ok(Self::UnknownPayload {
                payload_type: r#type,
                length: reader.remaining(),
            });
        };

        // Create the corresponding variant by decoding the payload accordingly
        Ok(match r#type {
            IncomingPayloadType::Proxy => Self::Proxy(reader.read_remaining_owned()),

            IncomingPayloadType::ReflectionQueueDry => {
                let protobuf::d2m::ReflectionQueueDry {} =
                    Self::decode_protobuf::<protobuf::d2m::ReflectionQueueDry>(reader)?;
                Self::ReflectionQueueDry
            },

            IncomingPayloadType::RolePromotedToLeader => {
                let protobuf::d2m::RolePromotedToLeader {} =
                    Self::decode_protobuf::<protobuf::d2m::RolePromotedToLeader>(reader)?;
                Self::RolePromotedToLeader
            },

            IncomingPayloadType::DevicesInfo => {
                Self::DevicesInfo(DevicesInfo::from(Self::decode_protobuf::<
                    protobuf::d2m::DevicesInfo,
                >(reader)?))
            },

            IncomingPayloadType::DropDeviceAck => {
                let protobuf::d2m::DropDeviceAck { device_id } =
                    Self::decode_protobuf::<protobuf::d2m::DropDeviceAck>(reader)?;
                Self::DropDeviceAck(D2xDeviceId(device_id))
            },

            IncomingPayloadType::BeginTransactionAck => {
                let protobuf::d2m::BeginTransactionAck {} =
                    Self::decode_protobuf::<protobuf::d2m::BeginTransactionAck>(reader)?;
                Self::BeginTransactionAck
            },

            IncomingPayloadType::CommitTransactionAck => {
                let protobuf::d2m::CommitTransactionAck {} =
                    Self::decode_protobuf::<protobuf::d2m::CommitTransactionAck>(reader)?;
                Self::CommitTransactionAck
            },

            IncomingPayloadType::TransactionRejected => {
                Self::TransactionRejected(TransactionRejected::from(Self::decode_protobuf::<
                    protobuf::d2m::TransactionRejected,
                >(reader)?))
            },

            IncomingPayloadType::TransactionEnded => {
                Self::TransactionEnded(TransactionEnded::from(Self::decode_protobuf::<
                    protobuf::d2m::TransactionEnded,
                >(reader)?))
            },

            IncomingPayloadType::ReflectAck => Self::ReflectAck(ReflectAck::decode(reader)?),

            IncomingPayloadType::Reflected => Self::Reflected(Reflected::decode(reader)?),
        })
    }
}

#[derive(Clone, Copy, strum::FromRepr, VariantNames, DebugVariantNames)]
#[repr(u8)]
enum OutgoingPayloadType {
    // Chat server proxying
    Proxy = 0x00,

    // Device management
    GetDevicesInfo = 0x30,
    DropDevice = 0x32,
    SetSharedDeviceData = 0x34,

    // Transactions
    BeginTransaction = 0x40,
    CommitTransaction = 0x42,

    // Reflection
    Reflect = 0x80,
    ReflectedAck = 0x83,
}

/// Acquires a device group lock for an atomic operation shared across the device group.
///
/// See [`protobuf::d2m::BeginTransaction`] for further details.
#[derive(Educe)]
#[educe(Debug)]
pub struct BeginTransaction {
    /// The transaction scope (`d2d.TransactionScope`), encrypted by `DGTSK.secret` and prefixed with a
    /// random nonce.
    #[educe(Debug(method(debug_slice_length)))]
    pub encrypted_scope: Vec<u8>,

    /// Time-to-live for this transaction. Once the TTL is reached, the mediator server will abort the
    /// transaction and disconnect the client. When not provided, the server's maximum transaction TTL will
    /// be used.
    pub ttl: Option<Duration>,
}
impl TryFrom<BeginTransaction> for protobuf::d2m::BeginTransaction {
    type Error = D2mProtocolError;

    fn try_from(BeginTransaction { encrypted_scope, ttl }: BeginTransaction) -> Result<Self, Self::Error> {
        Ok(Self {
            encrypted_scope,
            ttl: ttl.unwrap_or_default().as_secs().try_into().map_err(|_| {
                D2mProtocolError::ConversionError("Transaction TTL in seconds must fit a u32")
            })?,
        })
    }
}

/// Set the shared device data which is being sent to each device during login.
#[derive(Educe)]
#[educe(Debug)]
pub struct SharedDeviceData {
    /// Device data shared among devices (`d2d.SharedDeviceData`), encrypted by `DGSDDK.secret` and prefixed
    /// with a random nonce.
    #[educe(Debug(method(debug_slice_length)))]
    pub encrypted_shared_device_data: Vec<u8>,
}
impl From<SharedDeviceData> for protobuf::d2m::SetSharedDeviceData {
    fn from(
        SharedDeviceData {
            encrypted_shared_device_data,
        }: SharedDeviceData,
    ) -> Self {
        Self {
            encrypted_shared_device_data,
        }
    }
}

/// Reflect a message into the reflection queue of all other devices.
#[derive(Name, Educe)]
#[educe(Debug)]
pub struct Reflect {
    /// [`ReflectFlags`] set for this reflected message.
    pub flags: ReflectFlags,

    /// Unique number (per connection), used for acknowledgement.
    #[expect(clippy::struct_field_names, reason = "Consistency with protocol")]
    pub reflect_id: u32,

    /// The protobuf-encoded and encrypted data to be reflected, encrypted by `DGRK.secret` and prefixed with
    /// a random nonce.
    #[educe(Debug(method(debug_slice_length)))]
    pub envelope: Vec<u8>,
}
impl Reflect {
    const HEADER_LENGTH: u8 = 8;

    fn length(&self) -> usize {
        (Self::HEADER_LENGTH as usize).saturating_add(self.envelope.len())
    }

    fn encode_into(self, writer: &mut impl ByteWriter) -> Result<(), D2mProtocolError> {
        writer
            .run(|writer| {
                // Write header-length, reserved, flags, reflect-id and the envelope
                writer.write_u8(Self::HEADER_LENGTH)?;
                writer.write_u8(0)?;
                writer.write_u16_le(self.flags.0)?;
                writer.write_u32_le(self.reflect_id)?;
                writer.write(&self.envelope)
            })
            .map_err(|error| {
                D2mProtocolError::InternalError(D2mProtocolInternalErrorCause::EncodingFailed {
                    name: Self::NAME,
                    source: D2mProtocolInternalEncodingErrorCause::ByteWriterError(error),
                })
            })
    }
}

/// Acknowledges that a reflected message has been processed by the device.
#[derive(Name, Educe)]
#[educe(Debug)]
pub struct ReflectedAck {
    /// Refers to the reflect id as sent in the `reflected` message.
    pub reflect_id: u32,
}
impl ReflectedAck {
    const LENGTH: usize = Self::RESERVED.len() + 4;
    const RESERVED: [u8; 4] = [0_u8; 4];

    fn encode_into(self, writer: &mut impl ByteWriter) -> Result<(), D2mProtocolError> {
        writer
            .run(|writer| {
                // Write reserved bytes and reflect-id
                writer.write(&Self::RESERVED)?;
                writer.write_u32_le(self.reflect_id)
            })
            .map_err(|error| {
                D2mProtocolError::InternalError(D2mProtocolInternalErrorCause::EncodingFailed {
                    name: Self::NAME,
                    source: D2mProtocolInternalEncodingErrorCause::ByteWriterError(error),
                })
            })
    }
}

/// An outgoing payload to be sent to the mediator server during the post-handshake phase.
#[derive(Educe, Name, VariantNames)]
#[educe(Debug)]
pub enum OutgoingPayload {
    /// Proxied message to the chat server.
    Proxy(Vec<u8>),

    /// Request device information of all devices.
    GetDevicesInfo,

    /// Request to drop a device and free its device slot.
    DropDevice(D2xDeviceId),

    /// Acquires a device group lock for an atomic operation shared across the device group.
    BeginTransaction(BeginTransaction),

    /// Set the shared device data which is being sent to each device during login.
    SetSharedDeviceData(SharedDeviceData),

    /// Commits a transaction, releases a device group lock.
    CommitTransaction,

    /// Reflect a message into the reflection queue of all other devices.
    Reflect(Reflect),

    /// Acknowledges that a reflected message has been processed by the device.
    ReflectedAck(ReflectedAck),
}
impl PayloadEncoder for OutgoingPayload {
    fn type_and_length(&self) -> (u8, Option<usize>) {
        match self {
            Self::Proxy(data) => (OutgoingPayloadType::Proxy as u8, Some(data.len())),
            Self::GetDevicesInfo => (OutgoingPayloadType::GetDevicesInfo as u8, None),
            Self::DropDevice(_) => (OutgoingPayloadType::DropDevice as u8, None),
            Self::BeginTransaction(_) => (OutgoingPayloadType::BeginTransaction as u8, None),
            Self::SetSharedDeviceData(_) => (OutgoingPayloadType::SetSharedDeviceData as u8, None),
            Self::CommitTransaction => (OutgoingPayloadType::CommitTransaction as u8, None),
            Self::Reflect(reflect) => (OutgoingPayloadType::Reflect as u8, Some(reflect.length())),
            Self::ReflectedAck(_) => (
                OutgoingPayloadType::ReflectedAck as u8,
                Some(ReflectedAck::LENGTH),
            ),
        }
    }

    fn encode_into<TWriter>(self, writer: &mut TWriter) -> Result<(), D2mProtocolError>
    where
        TWriter: ByteWriter,
    {
        let name = self.variant_name();
        match self {
            Self::Proxy(data) => writer.write(&data).map_err(|error| {
                D2mProtocolError::InternalError(D2mProtocolInternalErrorCause::EncodingFailed {
                    name,
                    source: D2mProtocolInternalEncodingErrorCause::ByteWriterError(error),
                })
            }),

            Self::GetDevicesInfo => Self::encode_protobuf(protobuf::d2m::GetDevicesInfo {}, writer),

            Self::DropDevice(device_id) => Self::encode_protobuf(
                protobuf::d2m::DropDevice {
                    device_id: device_id.0,
                },
                writer,
            ),

            Self::BeginTransaction(begin_transaction) => Self::encode_protobuf(
                protobuf::d2m::BeginTransaction::try_from(begin_transaction)?,
                writer,
            ),

            Self::SetSharedDeviceData(shared_device_data) => Self::encode_protobuf(
                protobuf::d2m::SetSharedDeviceData::from(shared_device_data),
                writer,
            ),

            Self::CommitTransaction => Self::encode_protobuf(protobuf::d2m::CommitTransaction {}, writer),

            Self::Reflect(reflect) => reflect.encode_into(writer),

            Self::ReflectedAck(reflected_ack) => reflected_ack.encode_into(writer),
        }
    }
}
