//! Builds libthreema (d'oh!).
use std::io::Result;

#[cfg(feature = "uniffi")]
use uniffi as _;

fn main() -> Result<()> {
    // Configure and compile protobuf
    println!("cargo:rerun-if-changed=../threema-protocols/src/");
    let mut builder = prost_build::Config::new();

    // Definitions
    // -----------

    // Enums that should be convertable from/to a clap `ValueEnum`.
    let clap_convertable_enums = ["d2m.DeviceSlotState"];

    // Define enums that should be accessible across the FFI boundary.
    let ffi_accessible_enums = [
        "data_backup.Poll.PollState",
        "data_backup.Poll.PollDisplayMode",
        "data_backup.Poll.PollAnswerType",
        "data_backup.Poll.PollAnnounceType",
        "d2d_sync.Contact.AcquaintanceLevel",
        "d2d_sync.Contact.ActivityState",
        "d2d_sync.Contact.IdentityType",
        "d2d_sync.Contact.SyncState",
        "d2d_sync.Contact.VerificationLevel",
        "d2d_sync.Contact.WorkVerificationLevel",
        "d2d_sync.ConversationCategory",
        "d2d_sync.ConversationVisibility",
        "d2d_sync.Group.UserState",
        "d2d_sync.NotificationSoundPolicy",
        "d2d_sync.ReadReceiptPolicy",
        "d2d_sync.Settings.ContactSyncPolicy",
        "d2d_sync.Settings.GroupCallPolicy",
        "d2d_sync.Settings.KeyboardDataCollectionPolicy",
        "d2d_sync.Settings.O2oCallConnectionPolicy",
        "d2d_sync.Settings.O2oCallPolicy",
        "d2d_sync.Settings.O2oCallVideoPolicy",
        "d2d_sync.Settings.ScreenshotPolicy",
        "d2d_sync.Settings.UnknownContactPolicy",
        "d2d_sync.TypingIndicatorPolicy",
        "d2d_sync.WorkAvailabilityStatusCategory",
    ];

    // Apply definitions
    // -----------------

    // General protobuf annotations to apply.
    let builder = builder
        .message_attribute(".", "#[libthreema_macros::protobuf_annotations]")
        .enum_attribute(".", "#[derive(libthreema_macros::Name)]")
        .enable_type_names();

    // Apply attributes as required by above definition section.
    let builder = clap_convertable_enums.iter().fold(builder, |builder, path| {
        builder.enum_attribute(path, r#"#[cfg_attr(feature = "cli", derive(clap::ValueEnum))]"#)
    });
    let builder = ffi_accessible_enums.iter().fold(builder, |builder, path| {
        builder.enum_attribute(
            path,
            r#"
                #[cfg_attr(feature = "cli", derive(clap::ValueEnum))]
                #[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
                #[cfg_attr(
                    feature = "wasm",
                    derive(tsify::Tsify, serde::Serialize, serde::Deserialize),
                    serde(rename_all = "kebab-case"),
                    tsify(into_wasm_abi, from_wasm_abi)
                )]
            "#,
        )
    });

    builder.compile_protos(
        &[
            "../threema-protocols/src/common.proto",
            "../threema-protocols/src/data-backup.proto",
            "../threema-protocols/src/csp-e2e.proto",
            "../threema-protocols/src/data-backup.proto",
            "../threema-protocols/src/directory.proto",
            "../threema-protocols/src/md-d2d.proto",
            "../threema-protocols/src/md-d2d-join.proto",
            "../threema-protocols/src/md-d2d-sync.proto",
            "../threema-protocols/src/md-d2d-rendezvous.proto",
            "../threema-protocols/src/md-d2m.proto",
        ],
        &["../threema-protocols/src/"],
    )?;

    // Done
    Ok(())
}
