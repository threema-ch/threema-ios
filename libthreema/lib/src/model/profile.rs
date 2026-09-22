//! Contact or user profile related structs.

use educe::Educe;

use crate::utils::debug::debug_slice_length;

/// Media type of a profile picture image.
/// TODO(SE-625): Remove it and reuse the enum from protobuf.
#[derive(Clone, Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
pub enum ProfilePictureMediaType {
    /// JPEG.
    Jpeg,
}

/// A profile picture.
#[derive(Clone, Educe)]
#[educe(Debug)]
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
pub struct ProfilePicture {
    /// Media type of the profile picture.
    pub media_type: ProfilePictureMediaType,

    /// Bytes of the profile picture.
    #[educe(Debug(method(debug_slice_length)))]
    pub data: Vec<u8>,
}
