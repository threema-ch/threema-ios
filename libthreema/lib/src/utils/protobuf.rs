//! Protobuf utilities and extensions.
use duplicate::duplicate_item;
use rand::Rng as _;

use crate::{protobuf, utils::debug::Name};

impl<ProtobufMessage: prost::Name> Name for ProtobufMessage {
    const NAME: &'static str = ProtobufMessage::NAME;
}

const PADDING_FILL_VALUE: u8 = 0x33;

struct PaddingConstraint {
    /// The minimum amount of total bytes that must always be met by adding padding.
    ///
    /// Should be chosen so that it sufficiently prevents the enclosed content from being guessed, e.g. the
    /// average length of the largest enclosed variant.
    minimum_total_length: u16,

    /// The maximum amount of additional padding bytes that may be added.
    ///
    /// Should be chosen so that it doesn't blow up any length limitations.
    maximum_padding_length: u16,
}
impl PaddingConstraint {
    // The largest possible tag has 29 bits which is 5 bytes in varint encoding (29 bits divided into five 7
    // bit payloads). The largest amount of padding has 16 bits which is 3 bytes in varint encoding (16 bits
    // divided into three 7 bit payloads). Makes 8 bytes.
    const MAX_PADDING_OVERHEAD_LENGTH: usize = 5 + 3;
}

#[inline]
fn encode_to_vec_padded_internal<TMessage: prost::Message>(
    message: &TMessage,
    padding_tag: u32,
    constraint: &PaddingConstraint,
    mut padding_length: u16,
) -> Vec<u8> {
    // Ensure the minimum total length is always reached when encoding the message.
    let message_length = message.encoded_len();
    if message_length
        .checked_add(padding_length as usize)
        .expect("message_length + padding_length should not blow up a usize")
        < constraint.minimum_total_length as usize
    {
        padding_length = constraint
            .minimum_total_length
            .checked_sub(
                message_length
                    .try_into()
                    .expect("message_length must be < minimum_total_length and therefore u32"),
            )
            .expect("minimum_total_length must be > message_length");
    }

    // Encode message.
    let mut buffer = Vec::with_capacity(
        message_length
            .checked_add(padding_length as usize)
            .expect("message_length + padding_length should not blow up a usize")
            .checked_add(PaddingConstraint::MAX_PADDING_OVERHEAD_LENGTH)
            .expect(
                "message_length + MAX_PADDING_OVERHEAD_LENGTH + padding_length should not blow up a usize",
            ),
    );
    message.encode_raw(&mut buffer);

    // Encode padding header.
    prost::encoding::encode_key(
        padding_tag,
        prost::encoding::WireType::LengthDelimited,
        &mut buffer,
    );
    prost::encoding::encode_varint(padding_length.into(), &mut buffer);

    // Encode padding bytes (33emafill).
    buffer.resize(
        buffer
            .len()
            .checked_add(padding_length as usize)
            .expect("message_length + padding overhead + padding_length should not blow up a usize"),
        PADDING_FILL_VALUE,
    );

    buffer
}

/// Encode the message with padding to a newly allocated buffer. The padding is ensured to correctly take
/// the total encoded length into account but the varint encoding of the padding tag and length adds at
/// least two and at most eight bytes of variable overhead.
///
/// IMPORTANT: If another field with `padding_tag` exists that was encoded into the buffer, the resulting
/// message may either be deserialized into one or the other depending on the implementation.
fn encode_to_vec_padded<TMessage: prost::Message>(
    message: &TMessage,
    padding_tag: u32,
    constraint: &PaddingConstraint,
) -> Vec<u8> {
    // Generate random padding length based on the maximum padding length.
    let padding_length: u16 = rand::thread_rng().gen_range(0..constraint.maximum_padding_length);

    // Apply the randomly generated padding length to encode into a padded message.
    encode_to_vec_padded_internal(message, padding_tag, constraint, padding_length)
}

/// Post-encoding padding support to a message, so that the padding can be calculated based on the length of
/// the encoded message and appended afterwards.
///
/// TODO(LIB-47): This does not prevent the usage of `.encode_to_vec()`, so it can be easily missed.
pub(crate) trait PaddedMessage: prost::Message + Sized {
    /// Encode the message with padding to a newly allocated buffer. The padding is ensured to correctly take
    /// the total encoded length into account but the varint encoding of the padding tag and length adds at
    /// least two and at most eight bytes of variable overhead.
    fn encode_to_vec_padded(&self) -> Vec<u8>;

    /// Return the padding constraint that will be applied when the message is encoded with padding.
    #[cfg(test)]
    #[expect(private_interfaces, reason = "Only exists for testing")]
    fn padding_constraint() -> PaddingConstraint;

    /// Return the concrete padding of the message, mutable for modification by the test.
    #[cfg(test)]
    fn padding(&mut self) -> &mut Vec<u8>;

    /// Internal function to encode the message with given padding length `padding_length`.
    /// Used by tests to avoid randomness in message padding.
    #[cfg(test)]
    fn encode_to_vec_padded_internal(&self, padding_length: u16) -> Vec<u8>;
}

#[duplicate_item(
    [
        struct_name [ protobuf::csp_e2e::MessageMetadata ]
        padding_constraint_definition [
            PaddingConstraint { minimum_total_length: 32, maximum_padding_length: 64 }
        ]
    ]
    [
        struct_name [ protobuf::d2d::DeviceInfo ]
        padding_constraint_definition [
            PaddingConstraint { minimum_total_length: 64, maximum_padding_length: 128 }
        ]
    ]
    [
        struct_name [ protobuf::d2d::Envelope ]
        padding_constraint_definition [
            PaddingConstraint { minimum_total_length: 64, maximum_padding_length: 512 }
        ]
    ]
)]
impl PaddedMessage for struct_name {
    #[inline]
    fn encode_to_vec_padded(&self) -> Vec<u8> {
        encode_to_vec_padded(self, Self::PADDING_TAG, &padding_constraint_definition)
    }

    #[cfg(test)]
    #[inline]
    fn encode_to_vec_padded_internal(&self, padding_length: u16) -> Vec<u8> {
        encode_to_vec_padded_internal(
            self,
            Self::PADDING_TAG,
            &padding_constraint_definition,
            padding_length,
        )
    }

    #[cfg(test)]
    #[expect(private_interfaces, reason = "Only exists for testing")]
    fn padding_constraint() -> PaddingConstraint {
        padding_constraint_definition
    }

    #[cfg(test)]
    fn padding(&mut self) -> &mut Vec<u8> {
        #[expect(
            deprecated,
            reason = "Should not be directly accessed, but we need to access it for testing purposes"
        )]
        &mut self.padding
    }
}

#[cfg(test)]
mod tests {
    use rstest::rstest;

    use crate::{
        protobuf,
        utils::protobuf::{PADDING_FILL_VALUE, PaddedMessage, PaddingConstraint},
    };

    #[rstest]
    fn ensure_correct_protobuf_padding<TMessage>(
        #[values(
            protobuf::csp_e2e::MessageMetadata {
                #[expect(deprecated, reason = "Will be filled by encode_to_vec_padded")]
                padding: vec![],
                message_id: 0,
                created_at: 0,
                nickname: None,
            },
            protobuf::csp_e2e::MessageMetadata {
                #[expect(deprecated, reason = "Will be filled by encode_to_vec_padded")]
                padding: vec![],
                message_id: 1,
                created_at: 5,
                nickname: Some("x".repeat(64)),
            },
            protobuf::csp_e2e::MessageMetadata {
                #[expect(deprecated, reason = "Will be filled by encode_to_vec_padded")]
                padding: vec![],
                message_id: 1,
                created_at: 5,
                nickname: Some("x".repeat(256)),
            },
        )]
        message: TMessage,

        #[values(
            0,
            1,
            protobuf::csp_e2e::MessageMetadata::padding_constraint().maximum_padding_length.div_euclid(2),
            protobuf::csp_e2e::MessageMetadata::padding_constraint().maximum_padding_length,
        )]
        padding_length: u16,
    ) -> anyhow::Result<()>
    where
        TMessage: PaddedMessage + prost::Message + PartialEq<TMessage> + core::fmt::Debug + Default,
    {
        let constraint = TMessage::padding_constraint();

        // Encode message without padding for comparison.
        let encoded_without_padding = message.encode_to_vec();

        // Encode message with padding.
        let encoded_with_padding = message.encode_to_vec_padded_internal(padding_length);

        // Note: Due to the way protobuf is encoded, there is no guarantee that a message encoded without
        // padding is smaller than one with padding. But we will just assume that prost doesn't do wonky
        // non-deterministic stuff.

        // Ensure _some_ padding was added.
        assert!(encoded_with_padding.len() > encoded_without_padding.len());

        // Ensure maximum encoded padding length is not exceeded.
        {
            let padding_length = encoded_with_padding.len() - encoded_without_padding.len();
            assert!(
                padding_length
                    <= constraint.maximum_padding_length as usize
                        + PaddingConstraint::MAX_PADDING_OVERHEAD_LENGTH
            );
        }

        // Ensure minimum encoded padding length is not undershot.
        assert!(encoded_with_padding.len() >= constraint.minimum_total_length as usize);

        // Sanity-check for decoding the encoded message without padding.
        assert_eq!(TMessage::decode(encoded_without_padding.as_ref())?, message);

        // Decode the padded message and check its padding length and content.
        let mut decoded = TMessage::decode(encoded_with_padding.as_ref())?;
        assert!(decoded.padding().len() >= padding_length as usize);
        assert!(decoded.padding().len() <= constraint.maximum_padding_length as usize);
        assert!(
            decoded
                .padding()
                .iter()
                .all(|&padding| padding == PADDING_FILL_VALUE),
        );

        // Compare the content (after stripping the padding).
        decoded.padding().clear();
        assert_eq!(decoded, message);

        Ok(())
    }
}
