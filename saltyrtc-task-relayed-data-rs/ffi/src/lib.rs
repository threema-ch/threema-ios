//! FFI bindings for the Relayed Data Task.
//!
//! The bindings currently wrap the entire SaltyRTC client API.
//! The downside of this is that only one task can be specified, not multiple.
//! That's a problem that can be solved later on.
//!
//! The implementation makes use of the opaque pointer pattern.
//!
//! A note on pointers: All const pointers returned by Rust functions should not be modified
//! outside of Rust functions.
//!
//! Ultimately, these bindings allow C compatible programs to do the following things:
//!
//! - Instantiate a SaltyRTC client
//! - Connect to a server, do the server and peer handshake
//! - Send outgoing messages
//! - Receive incoming messages
//! - Receive events (like connection loss, for example)
//! - Terminate the connection
#![allow(non_camel_case_types)]

extern crate anyhow;
#[macro_use] extern crate lazy_static;
extern crate libc;
#[macro_use] extern crate log;
extern crate log4rs;
extern crate rmp_serde;
extern crate saltyrtc_client;
extern crate saltyrtc_task_relayed_data;
extern crate tokio_core;
extern crate tokio_timer;

mod connection;
mod constants;
mod nonblocking;
pub mod saltyrtc_client_ffi;

use std::convert::TryInto;
use std::ffi::CStr;
use std::io::{BufReader, Read};
use std::mem;
use std::ptr;
use std::sync::{Arc, RwLock};
use std::slice;
use std::time::Duration;

use libc::{uintptr_t, size_t, c_char};
use rmp_serde as rmps;
use saltyrtc_client::{SaltyClient, SaltyClientBuilder, CloseCode, WsClient, Event};
use saltyrtc_client::crypto::{KeyPair, PublicKey, AuthToken};
use saltyrtc_client::dep::futures::{Future, Stream, Sink};
use saltyrtc_client::dep::futures::future::Either;
use saltyrtc_client::dep::futures::sync::{mpsc, oneshot};
use saltyrtc_client::dep::native_tls::{TlsConnector, Protocol, Certificate};
use saltyrtc_client::dep::rmpv::Value;
use saltyrtc_client::dep::rmpv::decode::read_value;
use saltyrtc_client::errors::SaltyError;
use saltyrtc_client::tasks::{BoxedTask, Task};
pub use saltyrtc_client_ffi::{salty_client_t, salty_keypair_t, salty_remote_t, salty_event_loop_t};
use saltyrtc_task_relayed_data::{RelayedDataTask, MessageEvent, OutgoingMessage};
use tokio_core::reactor::{Core, Remote};
use tokio_timer::Timer;

use connection::Either3;
pub use constants::*;


// *** TYPES *** //

/// Result type with all potential error codes.
///
/// If no error happened, the value should be `OK` (0).
#[repr(u8)]
#[derive(Debug, PartialEq, Eq)]
pub enum salty_relayed_data_success_t {
    /// No error.
    OK = 0,

    /// One of the arguments was a `null` pointer.
    NULL_ARGUMENT = 1,

    /// Creation of the object failed.
    CREATE_FAILED = 2,

    /// The public key bytes are not valid.
    PUBKEY_INVALID = 3,

    /// The auth token bytes are not valid.
    AUTH_TOKEN_INVALID = 4,

    /// The trusted key bytes are not valid.
    TRUSTED_KEY_INVALID = 5,

    /// The server permanent public key bytes are not valid.
    SERVER_KEY_INVALID = 6,
}

/// The return value when creating a new client instance.
///
/// Note: Before accessing `client` or one of the channels, make sure to check
/// the `success` field for errors. If the creation of the client
/// was not successful, then the other pointers will be null.
#[repr(C)]
pub struct salty_relayed_data_client_ret_t {
    pub success: salty_relayed_data_success_t,
    pub client: *const salty_client_t,
    pub receiver_rx: *const salty_channel_receiver_rx_t,
    pub sender_tx: *const salty_channel_sender_tx_t,
    pub sender_rx: *const salty_channel_sender_rx_t,
    pub disconnect_tx: *const salty_channel_disconnect_tx_t,
    pub disconnect_rx: *const salty_channel_disconnect_rx_t,
}

/// The channel for receiving incoming messages.
///
/// On the Rust side, this is an `mpsc::UnboundedReceiver<MessageEvent>`.
pub enum salty_channel_receiver_rx_t {}

/// The channel for sending outgoing messages (sending end).
///
/// On the Rust side, this is an `mpsc::UnboundedSender<OutgoingMessage>`.
pub enum salty_channel_sender_tx_t {}

/// The channel for sending outgoing messages (receiving end).
///
/// On the Rust side, this is an `mpsc::UnboundedReceiver<OutgoingMessage>`.
pub enum salty_channel_sender_rx_t {}

/// The oneshot channel for closing the connection (sending end).
///
/// On the Rust side, this is an `oneshot::Sender<CloseCode>`.
pub enum salty_channel_disconnect_tx_t {}

/// The oneshot channel for closing the connection (receiving end).
///
/// On the Rust side, this is an `oneshot::Receiver<CloseCode>`.
pub enum salty_channel_disconnect_rx_t {}


/// The return value when initializing a connection.
///
/// Note: Before accessing `connect_future`, make sure to check the `success`
/// field for errors. If an error occurred, the other fields will be `null`.
#[repr(C)]
pub struct salty_client_init_ret_t {
    pub success: salty_client_init_success_t,
    pub handshake_future: *const salty_handshake_future_t,
    pub event_rx: *const salty_channel_event_rx_t,
    pub event_tx: *const salty_channel_event_tx_t,
}

/// A handshake future. This will be passed to the `salty_client_connect`
/// function.
///
/// On the Rust side, this is a `Box<Box<Future<Item=WsClient, Error=SaltyError>>>`.
/// The double box is used because the inner box is actually a trait object fat
/// pointer, pointing to both the data and the vtable.
pub enum salty_handshake_future_t {}

/// An event channel (sending end).
///
/// On the Rust side, this is an `UnboundedSender<Event>`.
pub enum salty_channel_event_tx_t {}

/// An event channel (receiving end).
///
/// On the Rust side, this is an `UnboundedReceiver<Event>`.
pub enum salty_channel_event_rx_t {}

/// Result type with all potential init error codes.
///
/// If no error happened, the value should be `INIT_OK` (0).
#[repr(u8)]
#[derive(Debug, PartialEq, Eq)]
pub enum salty_client_init_success_t {
    /// No error.
    INIT_OK = 0,

    /// One of the arguments was a `null` pointer.
    INIT_NULL_ARGUMENT = 1,

    /// The hostname is invalid (probably not UTF-8)
    INIT_INVALID_HOST = 2,

    /// TLS related error
    INIT_TLS_ERROR = 3,

    /// Certificate related error
    INIT_CERTIFICATE_ERROR = 4,

    /// Another initialization error
    INIT_ERROR = 9,
}

/// Result type with all potential connection error codes.
///
/// If no error happened, the value should be `CONNECT_OK` (0).
#[repr(u8)]
#[derive(Debug, PartialEq, Eq)]
pub enum salty_client_connect_success_t {
    /// No error.
    CONNECT_OK = 0,

    /// One of the arguments was a `null` pointer.
    CONNECT_NULL_ARGUMENT = 1,

    /// The hostname is invalid (probably not UTF-8)
    CONNECT_INVALID_HOST = 2,

    /// TLS related error
    CONNECT_TLS_ERROR = 3,

    /// Certificate related error
    CONNECT_CERTIFICATE_ERROR = 4,

    /// Another connection error
    CONNECT_ERROR = 9,
}

/// Result type with all potential disconnection error codes.
///
/// If no error happened, the value should be `DISCONNECT_OK` (0).
#[repr(u8)]
#[derive(Debug, PartialEq, Eq)]
pub enum salty_client_disconnect_success_t {
    /// No error.
    DISCONNECT_OK = 0,

    /// One of the arguments was a `null` pointer.
    DISCONNECT_NULL_ARGUMENT = 1,

    /// Another connection error
    DISCONNECT_ERROR = 9,
}

/// Result type with all potential error codes.
///
/// If no error happened, the value should be `SEND_OK` (0).
#[repr(u8)]
#[derive(Debug, PartialEq, Eq)]
pub enum salty_client_send_success_t {
    /// No error.
    SEND_OK = 0,

    /// One of the arguments was a `null` pointer.
    SEND_NULL_ARGUMENT = 1,

    /// Sending failed because the message was invalid
    SEND_MESSAGE_ERROR = 2,

    /// Sending failed
    SEND_ERROR = 9,
}

/// Possible message types.
#[repr(u8)]
#[derive(Debug, PartialEq, Eq)]
pub enum salty_msg_type_t {
    /// Incoming task message
    MSG_TASK = 0x01,

    /// Incoming application message.
    MSG_APPLICATION = 0x02,

    /// Incoming close message.
    MSG_CLOSE = 0x03,
}

/// A message event.
///
/// If the message type is `MSG_TASK` or `MSG_APPLICATION`, then the `msg_bytes` field
/// will point to the bytes of the decrypted message. Otherwise, the field is `null`.
///
/// If the event type is `MSG_CLOSE`, then the `close_code` field will
/// contain the close code. Otherwise, the field is `0`.
#[repr(C)]
pub struct salty_msg_t {
    msg_type: salty_msg_type_t,
    msg_bytes: *const u8,
    msg_bytes_len: uintptr_t,
    close_code: u16,
}

/// Possible event types.
#[repr(u8)]
#[derive(Debug, PartialEq, Eq)]
pub enum salty_event_type_t {
    /// A connection is being established.
    EVENT_CONNECTING = 0x01,

    /// Server handshake completed.
    EVENT_SERVER_HANDSHAKE_COMPLETED = 0x02,

    /// Peer handshake completed.
    EVENT_PEER_HANDSHAKE_COMPLETED = 0x03,

    /// A peer has disconnected from the server.
    EVENT_PEER_DISCONNECTED = 0x04,
}

/// An event.
///
/// If the event type is `EVENT_SERVER_HANDSHAKE_COMPLETED`, then the
/// `peer_connected` field will contain a boolean indicating whether or not a
/// peer is already connected to the server or not. Otherwise, the field is
/// always `false` and should be ignored.
///
/// If the event type is `EVENT_PEER_DISCONNECTED`, then the `peer_id` field
/// will contain the peer id. Otherwise, the field is `0`.
#[repr(C)]
pub struct salty_event_t {
    event_type: salty_event_type_t,
    peer_connected: bool,
    peer_id: u8,
}

/// Result type with all potential event receiving error codes.
///
/// If no error happened, the value should be `RECV_OK` (0).
#[repr(u8)]
#[derive(Debug, PartialEq, Eq)]
pub enum salty_client_recv_success_t {
    /// No error.
    RECV_OK = 0,

    /// One of the arguments was a `null` pointer.
    RECV_NULL_ARGUMENT = 1,

    /// No data is available (timeout reached).
    RECV_NO_DATA = 2,

    /// The stream has ended and *SHOULD NOT* be polled again.
    RECV_STREAM_ENDED = 3,

    /// Another receiving error
    RECV_ERROR = 9,
}

/// The return value when trying to receive a message.
///
/// Note: Before accessing `msg`, make sure to check the `success` field
/// for errors. If an error occurred, the `msg` field will be `null`.
#[repr(C)]
pub struct salty_client_recv_msg_ret_t {
    pub success: salty_client_recv_success_t,
    pub msg: *const salty_msg_t,
}

/// The return value when trying to receive an event.
///
/// Note: Before accessing `event`, make sure to check the `success` field
/// for errors. If an error occurred, the `event` field will be `null`.
#[repr(C)]
pub struct salty_client_recv_event_ret_t {
    pub success: salty_client_recv_success_t,
    pub event: *const salty_event_t,
}

/// The return value when encrypting or decrypting raw data.
///
/// Note: Before accessing `bytes`, make sure to check the `success` field for
/// errors. If an error occurred, the other fields will be `null`.
#[repr(C)]
pub struct salty_client_encrypt_decrypt_ret_t {
    success: salty_client_encrypt_decrypt_success_t,
    bytes: *const u8,
    bytes_len: size_t,
}

/// Result type with all potential encrypt/decrypt error codes.
///
/// If no error happened, the value should be `ENCRYPT_DECRYPT_OK` (0).
#[repr(u8)]
#[derive(Debug, PartialEq, Eq)]
pub enum salty_client_encrypt_decrypt_success_t {
    /// No error.
    ENCRYPT_DECRYPT_OK = 0,

    /// One of the arguments was a `null` pointer.
    ENCRYPT_DECRYPT_NULL_ARGUMENT = 1,

    /// The peer has not yet been determined.
    ENCRYPT_DECRYPT_NO_PEER = 2,

    /// Other error
    ENCRYPT_DECRYPT_ERROR = 9,
}


// *** HELPER FUNCTIONS *** //

/// Helper function to return error values when creating a client instance.
fn make_client_create_error(reason: salty_relayed_data_success_t) -> salty_relayed_data_client_ret_t {
    salty_relayed_data_client_ret_t {
        success: reason,
        client: ptr::null(),
        receiver_rx: ptr::null(),
        sender_tx: ptr::null(),
        sender_rx: ptr::null(),
        disconnect_tx: ptr::null(),
        disconnect_rx: ptr::null(),
    }
}

struct ClientBuilderRet {
    builder: SaltyClientBuilder,
    receiver_rx: mpsc::UnboundedReceiver<MessageEvent>,
    sender_tx: mpsc::UnboundedSender<OutgoingMessage>,
    sender_rx: mpsc::UnboundedReceiver<OutgoingMessage>,
    disconnect_tx: oneshot::Sender<CloseCode>,
    disconnect_rx: oneshot::Receiver<CloseCode>,
}

/// Helper function to parse arguments and to create a new `SaltyClientBuilder`.
unsafe fn create_client_builder(
    keypair: *const salty_keypair_t,
    server_public_permanent_key: *const u8,
    remote: *const salty_remote_t,
    ping_interval_seconds: u32,
) -> Result<ClientBuilderRet, salty_relayed_data_success_t> {
    trace!("create_client_builder");

    // Null checks
    if keypair.is_null() {
        error!("Keypair pointer is null");
        return Err(salty_relayed_data_success_t::NULL_ARGUMENT);
    }
    if remote.is_null() {
        error!("Remote pointer is null");
        return Err(salty_relayed_data_success_t::NULL_ARGUMENT);
    }

    // Recreate pointer instances
    let keypair = Box::from_raw(keypair as *mut KeyPair);
    let remote = Box::from_raw(remote as *mut Remote);

    // Create communication channels
    // TODO: The sender should not be created here, it should be extracted from the task!
    let (receiver_tx, receiver_rx) = mpsc::unbounded();
    let (sender_tx, sender_rx) = mpsc::unbounded();
    let (disconnect_tx, disconnect_rx) = oneshot::channel();

    // Instantiate task
    let task = RelayedDataTask::new(*remote, receiver_tx);

    // Determine ping interval
    let interval = match ping_interval_seconds {
        0 => None,
        secs => Some(Duration::from_secs(secs as u64))
    };

    // Create builder instance
    let mut builder = SaltyClient::build(*keypair)
        .add_task(Box::new(task) as BoxedTask)
        .with_ping_interval(interval);

    // Verify server public permanent key (if present)
    if server_public_permanent_key.is_null() {
        warn!("Not supplying server public permanent key");
    } else {
        let pubkey_bytes: [u8; 32] = slice::from_raw_parts(server_public_permanent_key, 32)
            .try_into()
            .expect("Could not convert public key slice to array");
        debug!("Supplying server public permanent key");
        trace!("Expecting server public permanent key to match {:?}", pubkey_bytes);
        builder = builder.with_server_key(PublicKey::from(pubkey_bytes));
    }

    Ok(ClientBuilderRet {
        builder,
        receiver_rx,
        sender_tx,
        sender_rx,
        disconnect_tx,
        disconnect_rx,
    })
}


// *** MAIN FUNCTIONALITY *** //

/// Initialize a new SaltyRTC client as initiator with the Relayed Data task.
///
/// Parameters:
///     keypair (`*salty_keypair_t`, moved):
///         Pointer to a key pair.
///     remote (`*salty_remote_t`, moved):
///         Pointer to an event loop remote handle.
///     ping_interval_seconds (`uint32_t`, copied):
///         Request that the server sends a WebSocket ping message at the specified interval.
///         Set this argument to `0` to disable ping messages.
///     trusted_responder_key (`*uint8_t` or `null`, borrowed):
///         The trusted responder public key. If set, this must be a pointer to a 32 byte
///         `uint8_t` array. Set this to null when not restoring a trusted session.
///     server_public_permanent_key (`*uint8_t` or `null`, borrowed):
///         The server public permanent key. If set, this must be a pointer to a 32 byte
///         `uint8_t` array. Set this to null to not validate the server public key.
/// Returns:
///     A `salty_relayed_data_client_ret_t` struct.
#[no_mangle]
pub unsafe extern "C" fn salty_relayed_data_initiator_new(
    keypair: *const salty_keypair_t,
    remote: *const salty_remote_t,
    ping_interval_seconds: u32,
    trusted_responder_key: *const u8,
    server_public_permanent_key: *const u8,
) -> salty_relayed_data_client_ret_t {
    trace!("salty_relayed_data_initiator_new");

    // Parse arguments and create SaltyRTC builder
    let ret = match create_client_builder(keypair, server_public_permanent_key, remote, ping_interval_seconds) {
        Ok(val) => val,
        Err(reason) => return make_client_create_error(reason),
    };

    // Parse trusted responder key
    let trusted_key_opt = if trusted_responder_key.is_null() {
        None
    } else {
        // Get bytes
        let trusted_key_bytes: [u8; 32] = slice::from_raw_parts(trusted_responder_key, 32)
            .try_into()
            .expect("Could not convert trusted key slice to array");

        // Just to rule out stupid mistakes, make sure that the public key is not all-zero
        if trusted_key_bytes.iter().all(|&x| x == 0) {
            error!("Trusted key bytes are all zero!");
            return make_client_create_error(salty_relayed_data_success_t::TRUSTED_KEY_INVALID);
        }

        // Parse
        Some(PublicKey::from(trusted_key_bytes))
    };

    // Create client instance
    let client_res = match trusted_key_opt {
        Some(key) => ret.builder.initiator_trusted(key),
        None => ret.builder.initiator(),
    };
    let client = match client_res {
        Ok(client) => client,
        Err(e) => {
            error!("Could not instantiate SaltyClient: {}", e);
            return make_client_create_error(salty_relayed_data_success_t::CREATE_FAILED);
        },
    };

    salty_relayed_data_client_ret_t {
        success: salty_relayed_data_success_t::OK,
        client: Arc::into_raw(Arc::new(RwLock::new(client))) as *const salty_client_t,
        receiver_rx: Box::into_raw(Box::new(ret.receiver_rx)) as *const salty_channel_receiver_rx_t,
        sender_tx: Box::into_raw(Box::new(ret.sender_tx)) as *const salty_channel_sender_tx_t,
        sender_rx: Box::into_raw(Box::new(ret.sender_rx)) as *const salty_channel_sender_rx_t,
        disconnect_tx: Box::into_raw(Box::new(ret.disconnect_tx)) as *const salty_channel_disconnect_tx_t,
        disconnect_rx: Box::into_raw(Box::new(ret.disconnect_rx)) as *const salty_channel_disconnect_rx_t,
    }
}

/// Initialize a new SaltyRTC client as responder with the Relayed Data task.
///
/// Parameters:
///     keypair (`*salty_keypair_t`, moved):
///         Pointer to a key pair.
///     remote (`*salty_remote_t`, moved):
///         Pointer to an event loop remote handle.
///     ping_interval_seconds (`uint32_t`, copied):
///         Request that the server sends a WebSocket ping message at the specified interval.
///         Set this argument to `0` to disable ping messages.
///     initiator_pubkey (`*uint8_t`, borrowed):
///         Public key of the initiator. A 32 byte `uint8_t` array.
///     auth_token (`*uint8_t` or `null`, borrowed):
///         One-time auth token from the initiator. If set, this must be a pointer
///         to a 32 byte `uint8_t` array. Set this to `null` when restoring a trusted session.
///     server_public_permanent_key (`*uint8_t` or `null`, borrowed):
///         The server public permanent key. If set, this must be a pointer to a 32 byte
///         `uint8_t` array. Set this to null to not validate the server public key.
/// Returns:
///     A `salty_relayed_data_client_ret_t` struct.
#[no_mangle]
pub unsafe extern "C" fn salty_relayed_data_responder_new(
    keypair: *const salty_keypair_t,
    remote: *const salty_remote_t,
    ping_interval_seconds: u32,
    initiator_pubkey: *const u8,
    auth_token: *const u8,
    server_public_permanent_key: *const u8,
) -> salty_relayed_data_client_ret_t {
    trace!("salty_relayed_data_responder_new");

    // Parse arguments and create SaltyRTC builder
    let ret = match create_client_builder(keypair, server_public_permanent_key, remote, ping_interval_seconds) {
        Ok(val) => val,
        Err(reason) => return make_client_create_error(reason),
    };

    // Get public key slice
    if initiator_pubkey.is_null() {
        error!("Initiator public key is a null pointer");
        return make_client_create_error(salty_relayed_data_success_t::NULL_ARGUMENT);
    }
    let pubkey_bytes: [u8; 32] = slice::from_raw_parts(initiator_pubkey, 32)
        .try_into()
        .expect("Could not convert public key slice to array");

    // Just to rule out stupid mistakes, make sure that the public key is not all-zero
    if pubkey_bytes.iter().all(|&x| x == 0) {
        error!("Public key bytes are all zero!");
        return make_client_create_error(salty_relayed_data_success_t::PUBKEY_INVALID);
    }

    // Parse public key
    let pubkey = PublicKey::from(pubkey_bytes);

    // Parse auth token
    let auth_token_opt = if auth_token.is_null() {
        None
    } else {
        // Get slice
        let auth_token_slice: &[u8] = slice::from_raw_parts(auth_token, 32);

        // Just to rule out stupid mistakes, make sure that the token is not all-zero
        if auth_token_slice.iter().all(|&x| x == 0) {
            error!("Auth token bytes are all zero!");
            return make_client_create_error(salty_relayed_data_success_t::AUTH_TOKEN_INVALID);
        }

        // Parse
        match AuthToken::from_slice(auth_token_slice) {
            Ok(token) => Some(token),
            Err(e) => {
                error!("Could not parse auth token bytes: {}", e);
                return make_client_create_error(salty_relayed_data_success_t::AUTH_TOKEN_INVALID);
            }
        }
    };

    // Create client instance
    let client_res = match auth_token_opt {
        // An auth token was set. Initiate a new session.
        Some(token) => ret.builder.responder(pubkey, token),
        // No auth token was set. Restore trusted session.
        None => ret.builder.responder_trusted(pubkey),
    };
    let client = match client_res {
        Ok(client) => client,
        Err(e) => {
            error!("Could not instantiate SaltyClient: {}", e);
            return make_client_create_error(salty_relayed_data_success_t::CREATE_FAILED);
        },
    };

    salty_relayed_data_client_ret_t {
        success: salty_relayed_data_success_t::OK,
        client: Arc::into_raw(Arc::new(RwLock::new(client))) as *const salty_client_t,
        receiver_rx: Box::into_raw(Box::new(ret.receiver_rx)) as *const salty_channel_receiver_rx_t,
        sender_tx: Box::into_raw(Box::new(ret.sender_tx)) as *const salty_channel_sender_tx_t,
        sender_rx: Box::into_raw(Box::new(ret.sender_rx)) as *const salty_channel_sender_rx_t,
        disconnect_tx: Box::into_raw(Box::new(ret.disconnect_tx)) as *const salty_channel_disconnect_tx_t,
        disconnect_rx: Box::into_raw(Box::new(ret.disconnect_rx)) as *const salty_channel_disconnect_rx_t,
    }
}

/// Get a pointer to the auth token bytes from a `salty_client_t` instance.
///
/// Ownership:
///     The memory is still owned by the `salty_client_t` instance.
///     Do not reuse the reference after the `salty_client_t` instance has been freed!
/// Returns:
///     A null pointer if the parameter is null, if no auth token is set on the client
///     or if the arc cannot be borrowed.
///     Pointer to a 32 byte `uint8_t` array otherwise.
#[no_mangle]
pub unsafe extern "C" fn salty_relayed_data_client_auth_token(
    ptr: *const salty_client_t,
) -> *const u8 {
    trace!("salty_relayed_data_client_auth_token");

    if ptr.is_null() {
        error!("salty_relayed_data_client_auth_token: Tried to dereference a null pointer");
        return ptr::null();
    }

    // Recreate Arc from pointer
    let client_arc: Arc<RwLock<SaltyClient>> = Arc::from_raw(ptr as *const RwLock<SaltyClient>);

    // Determine pointer to auth token
    let retval = match client_arc.read() {
        Ok(client_ref) => match client_ref.auth_token() {
            Some(token) => token.secret_key_bytes().as_ptr(),
            None => ptr::null(),
        },
        Err(e) => {
            error!("salty_relayed_data_client_auth_token: Could not read-lock client: {}", e);
            ptr::null()
        }
    };

    // We must ensure that the Arc is not dropped, otherwise – if it's the last reference to
    // the underlying data – the data on the heap would be dropped too.
    mem::forget(client_arc);

    retval
}

/// Free a SaltyRTC client with the Relayed Data task.
#[no_mangle]
pub unsafe extern "C" fn salty_relayed_data_client_free(
    ptr: *const salty_client_t,
) {
    trace!("salty_relayed_data_client_free");

    if ptr.is_null() {
        warn!("salty_relayed_data_client_free: Tried to free a null pointer");
        return;
    }
    Arc::from_raw(ptr as *const RwLock<SaltyClient>);
}

/// Free a `salty_channel_receiver_rx_t` instance.
#[no_mangle]
pub unsafe extern "C" fn salty_channel_receiver_rx_free(
    ptr: *const salty_channel_receiver_rx_t,
) {
    trace!("salty_channel_receiver_rx_free");

    if ptr.is_null() {
        warn!("salty_channel_receiver_rx_free: Tried to free a null pointer");
        return;
    }
    Box::from_raw(ptr as *mut mpsc::UnboundedReceiver<MessageEvent>);
}

/// Free a `salty_channel_sender_tx_t` instance.
#[no_mangle]
pub unsafe extern "C" fn salty_channel_sender_tx_free(
    ptr: *const salty_channel_sender_tx_t,
) {
    trace!("salty_channel_sender_tx_free");

    if ptr.is_null() {
        warn!("salty_channel_sender_tx_free: Tried to free a null pointer");
        return;
    }
    Box::from_raw(ptr as *mut mpsc::UnboundedSender<OutgoingMessage>);
}

/// Free a `salty_channel_sender_rx_t` instance.
#[no_mangle]
pub unsafe extern "C" fn salty_channel_sender_rx_free(
    ptr: *const salty_channel_sender_rx_t,
) {
    trace!("salty_channel_sender_rx_free");

    if ptr.is_null() {
        warn!("salty_channel_sender_rx_free: Tried to free a null pointer");
        return;
    }
    Box::from_raw(ptr as *mut mpsc::UnboundedReceiver<OutgoingMessage>);
}

/// Free a `salty_channel_disconnect_tx_t` instance.
#[no_mangle]
pub unsafe extern "C" fn salty_channel_disconnect_tx_free(
    ptr: *const salty_channel_disconnect_tx_t,
) {
    trace!("salty_channel_disconnect_tx_free");

    if ptr.is_null() {
        warn!("salty_channel_disconnect_tx_free: Tried to free a null pointer");
        return;
    }
    Box::from_raw(ptr as *mut oneshot::Sender<CloseCode>);
}

/// Free a `salty_channel_disconnect_rx_t` instance.
#[no_mangle]
pub unsafe extern "C" fn salty_channel_disconnect_rx_free(
    ptr: *const salty_channel_disconnect_rx_t,
) {
    trace!("salty_channel_disconnect_tx_free");

    if ptr.is_null() {
        warn!("salty_channel_disconnect_rx_free: Tried to free a null pointer");
        return;
    }
    let _ = Box::from_raw(ptr as *mut oneshot::Receiver<CloseCode>);
}

/// Free a `salty_channel_event_tx_t` instance.
#[no_mangle]
pub unsafe extern "C" fn salty_channel_event_tx_free(
    ptr: *const salty_channel_event_tx_t,
) {
    trace!("salty_channel_event_tx_free");

    if ptr.is_null() {
        warn!("salty_channel_event_tx_t: Tried to free a null pointer");
        return;
    }
    Box::from_raw(ptr as *mut mpsc::UnboundedSender<Event>);
}

/// Free a `salty_channel_event_rx_t` instance.
#[no_mangle]
pub unsafe extern "C" fn salty_channel_event_rx_free(
    ptr: *const salty_channel_event_rx_t,
) {
    trace!("salty_channel_event_rx_free");

    if ptr.is_null() {
        warn!("salty_channel_event_rx_free: Tried to free a null pointer");
        return;
    }
    Box::from_raw(ptr as *mut mpsc::UnboundedReceiver<Event>);
}


// *** CONNECTION *** //

/// Prepare a connection to the specified SaltyRTC server, but do not connect yet.
///
/// Parameters:
///     host (`*c_char`, null terminated, borrowed):
///         Null terminated UTF-8 encoded C string containing the SaltyRTC server hostname.
///     port (`*uint16_t`, copied):
///         SaltyRTC server port.
///     client (`*salty_client_t`, borrowed):
///         Pointer to a `salty_client_t` instance.
///     event_loop (`*salty_event_loop_t`, borrowed):
///         The event loop that is also associated with the task.
///     timeout_s (`uint16_t`, copied):
///         Connection and handshake timeout in seconds. Set value to `0` for no timeout.
///     ca_cert (`*uint8_t` or `NULL`, borrowed):
///         Optional pointer to bytes of a DER encoded CA certificate.
///         When no certificate is set, the OS trust chain is used.
///     ca_cert_len (`uint32_t`, copied):
///         When the `ca_cert` argument is not `NULL`, then this must be
///         set to the number of certificate bytes. Otherwise, set it to 0.
#[no_mangle]
pub unsafe extern "C" fn salty_client_init(
    host: *const c_char,
    port: u16,
    client: *const salty_client_t,
    event_loop: *const salty_event_loop_t,
    timeout_s: u16,
    ca_cert: *const u8,
    ca_cert_len: u32,
) -> salty_client_init_ret_t {
    trace!("salty_client_init: Initializing");

    // Helper function to return errors.
    fn make_init_ret_error(success: salty_client_init_success_t) -> salty_client_init_ret_t {
        salty_client_init_ret_t {
            success,
            handshake_future: ptr::null(),
            event_rx: ptr::null(),
            event_tx: ptr::null(),
        }
    }

    // Null pointer checks
    if host.is_null() {
        error!("Hostname pointer is null");
        return make_init_ret_error(salty_client_init_success_t::INIT_NULL_ARGUMENT);
    }
    if client.is_null() {
        error!("Client pointer is null");
        return make_init_ret_error(salty_client_init_success_t::INIT_NULL_ARGUMENT);
    }
    if event_loop.is_null() {
        error!("Event loop pointer is null");
        return make_init_ret_error(salty_client_init_success_t::INIT_NULL_ARGUMENT);
    }

    // Get host string
    let hostname_cstr = CStr::from_ptr(host);
    let hostname = match hostname_cstr.to_str() {
        Ok(host) => host,
        Err(e) => {
            error!("Host argument is not valid UTF-8: {}", e);
            trace!("Host bytes (without null termination): {:?}", hostname_cstr.to_bytes());
            return make_init_ret_error(salty_client_init_success_t::INIT_INVALID_HOST);
        },
    };

    // Recreate client Arc
    let client_arc: Arc<RwLock<SaltyClient>> = Arc::from_raw(client as *const RwLock<SaltyClient>);

    // Clone Arc so that the client instance can be reused
    let client_arc_connect = client_arc.clone();
    let client_arc_handshake = client_arc.clone();
    mem::forget(client_arc);

    // Get event loop reference
    let core = &mut *(event_loop as *mut Core) as &mut Core;

    // Read CA certificate (if present)
    let ca_cert_opt: Option<Certificate> = if ca_cert.is_null() {
        debug!("Using system CA chain");
        None
    } else {
        debug!("Reading CA certificate");
        let bytes: &[u8] = slice::from_raw_parts(ca_cert, ca_cert_len as usize);
        Some(match Certificate::from_der(bytes) {
            Ok(cert) => cert,
            Err(e) => {
                error!("Could not parse DER encoded CA certificate: {}", e);
                return make_init_ret_error(salty_client_init_success_t::INIT_CERTIFICATE_ERROR);
            }
        })
    };

    // Create TlsConnector
    let mut tls_builder = TlsConnector::builder();
    tls_builder.min_protocol_version(Some(Protocol::Tlsv10));
    if let Some(cert) = ca_cert_opt {
        tls_builder.add_root_certificate(cert);
    }
    let tls_connector = match tls_builder.build() {
        Ok(val) => val,
        Err(e) => {
            error!("Could not create TlsConnector: {}", e);
            return make_init_ret_error(salty_client_init_success_t::INIT_TLS_ERROR);
        }
    };


    // Create connect future
    let (connect_future, event_channel) = match saltyrtc_client::connect(
        hostname,
        port,
        Some(tls_connector),
        &core.handle(),
        client_arc_connect,
    ) {
        Ok(data) => data,
        Err(e) => {
            error!("Could not create connect future: {}", e);
            return make_init_ret_error(salty_client_init_success_t::INIT_ERROR);
        },
    };

    // Forget about reactor core
    mem::forget(core);

    // Split event channel
    let (event_tx, event_rx) = event_channel.split();

    // Create handshake future
    let timeout = match timeout_s {
        0 => None,
        seconds => Some(Duration::from_secs(seconds as u64)),
    };
    let event_tx_clone = event_tx.clone();
    let handshake_future = connect_future
        .and_then(move |ws_client| saltyrtc_client::do_handshake(
            ws_client,
            client_arc_handshake,
            event_tx_clone,
            timeout,
        ));
    let handshake_future_box: Box<dyn Future<Item=WsClient, Error=SaltyError>> = Box::new(handshake_future);

    salty_client_init_ret_t {
        success: salty_client_init_success_t::INIT_OK,
        handshake_future: Box::into_raw(Box::new(handshake_future_box)) as *const salty_handshake_future_t,
        event_tx: Box::into_raw(Box::new(event_tx)) as *const salty_channel_event_tx_t,
        event_rx: Box::into_raw(Box::new(event_rx)) as *const salty_channel_event_rx_t,
    }
}

/// Connect to the specified SaltyRTC server, do the server and peer handshake
/// and run the task loop.
///
/// This is a blocking call. It will end once the connection has been terminated.
/// You should probably run this in a separate thread.
///
/// Parameters:
///     handshake_future (`*salty_handshake_future_t`, moved):
///         Pointer to the handshake future, created with `salty_client_init`.
///     client (`*salty_client_t`, borrowed):
///         Pointer to a `salty_client_t` instance.
///     event_loop (`*salty_event_loop_t`, borrowed):
///         The event loop that is also associated with the task.
///     event_tx (`*salty_channel_event_tx_t`, moved):
///         The sending end of the channel for incoming events.
///         This object is returned from `salty_client_init`.
///     sender_rx (`*salty_channel_sender_rx_t`, moved):
///         The receiving end of the channel for outgoing messages.
///         This object is returned when creating a client instance.
///     disconnect_rx (`*salty_channel_disconnect_rx_t`, moved):
///         The receiving end of the channel for closing the connection.
///         This object is returned when creating a client instance.
#[no_mangle]
pub unsafe extern "C" fn salty_client_connect(
    handshake_future: *const salty_handshake_future_t,
    client: *const salty_client_t,
    event_loop: *const salty_event_loop_t,
    event_tx: *const salty_channel_event_tx_t,
    sender_rx: *const salty_channel_sender_rx_t,
    disconnect_rx: *const salty_channel_disconnect_rx_t,
) -> salty_client_connect_success_t {
    trace!("salty_client_connect: Initializing");

    // Null pointer checks
    if sender_rx.is_null() {
        error!("Sender RX channel pointer is null");
        return salty_client_connect_success_t::CONNECT_NULL_ARGUMENT;
    }
    if disconnect_rx.is_null() {
        error!("Disconnect RX channel pointer is null");
        return salty_client_connect_success_t::CONNECT_NULL_ARGUMENT;
    }

    // Recreate client Arc
    let client_arc: Arc<RwLock<SaltyClient>> = Arc::from_raw(client as *const RwLock<SaltyClient>);

    // Clone Arc so that the client instance can be reused
    let client_arc_task_loop = client_arc.clone();
    mem::forget(client_arc);

    // Get event loop reference
    let core = &mut *(event_loop as *mut Core) as &mut Core;

    // Get event channel sender reference
    let event_tx_box = Box::from_raw(event_tx as *mut mpsc::UnboundedSender<Event>);

    // Get handshake future reference
    let handshake_future_box = Box::from_raw(
        handshake_future as *mut Box<dyn Future<Item=WsClient, Error=SaltyError>>
    );

    // Get channel sender instances
    let sender_rx_box = Box::from_raw(sender_rx as *mut mpsc::UnboundedReceiver<OutgoingMessage>);
    let disconnect_rx_box = Box::from_raw(disconnect_rx as *mut oneshot::Receiver<CloseCode>);

    // Run handshake future to completion
    let (ws_client, disconnect_rx_box) = match core.run((*handshake_future_box).select2(disconnect_rx_box)) {
        // Handshake done
        Ok(Either::A((ws_client, disconnect_rx_box))) => {
            info!("Handshake done");
            (ws_client, disconnect_rx_box)
        },

        // Disconnect requested
        Ok(Either::B(_)) => {
            info!("Handshake ended (disconnected by us)");
            return salty_client_connect_success_t::CONNECT_OK;
        },

        // Errors
        Err(Either::A((e, _))) => {
            error!("Connection error: {}", e);
            return salty_client_connect_success_t::CONNECT_ERROR;
        },
        Err(Either::B((e, _))) => {
            error!("Error while listening for disconnect: {}", e);
            return salty_client_connect_success_t::CONNECT_ERROR;
        },
    };

    // Create task loop future
    let (task, task_loop) = match saltyrtc_client::task_loop(
        ws_client,
        client_arc_task_loop,
        *event_tx_box,
    ) {
        Ok(val) => val,
        Err(e) => {
            error!("Could not start task loop: {}", e);
            return salty_client_connect_success_t::CONNECT_ERROR;
        },
    };

    // Get access to task tx channel
    let task_sender: mpsc::UnboundedSender<OutgoingMessage> = {
        // Lock task mutex
        let mut task_locked = match task.lock() {
            Ok(guard) => guard,
            Err(e) => {
                error!("Could not lock task mutex: {}", e);
                return salty_client_connect_success_t::CONNECT_ERROR;
            }
        };

        // Downcast generic Task to a RelayedDataTask
        let rdt: &mut RelayedDataTask = {
            let downcast_res = (&mut **task_locked as &mut dyn Task)
                .downcast_mut::<RelayedDataTask>();
            match downcast_res {
                Some(task) => task,
                None => {
                    error!("Could not downcast task instance");
                    return salty_client_connect_success_t::CONNECT_ERROR;
                }
            }
        };

        match rdt.get_sender() {
            Ok(sender) => sender,
            Err(e) => {
                error!("Could not get task sender: {}", e);
                return salty_client_connect_success_t::CONNECT_ERROR;
            }
        }
    };

    // Forward outgoing messages to task
    let send_loop = (*sender_rx_box).forward(
        task_sender.sink_map_err(|e| error!("Could not sink message: {}", e))
    );

    // Run task loop future to completion
    let connection = connection::new(*disconnect_rx_box, send_loop, task_loop);
    match core.run(connection) {
        // Disconnect requested
        Ok(Either3::A(_)) => {
            info!("Connection ended (disconnected by us)");
            salty_client_connect_success_t::CONNECT_OK
        },

        // All OK
        Ok(Either3::B(_)) |
        Ok(Either3::C(_)) => {
            info!("Connection ended (closed by ");
            salty_client_connect_success_t::CONNECT_OK
        }

        Err(Either3::A(e)) => {
            error!("Disconnect receiver error: {}", e);
            salty_client_connect_success_t::CONNECT_ERROR
        },

        Err(Either3::B(_)) => {
            error!("Send loop error");
            salty_client_connect_success_t::CONNECT_ERROR
        },

        Err(Either3::C(e)) => {
            error!("Task loop error: {}", e);
            salty_client_connect_success_t::CONNECT_ERROR
        },
    }
}

enum OutgoingMessageType {
    Task,
    Application,
}

unsafe fn salty_client_send_bytes(
    msg_type: OutgoingMessageType,
    sender_tx: *const salty_channel_sender_tx_t,
    msg: *const u8,
    msg_len: u32,
) -> salty_client_send_success_t {
    trace!("salty_client_send_bytes");

    // Null pointer checks
    if sender_tx.is_null() {
        error!("Sender channel pointer is null");
        return salty_client_send_success_t::SEND_NULL_ARGUMENT;
    }
    if msg.is_null() {
        error!("Message pointer is null");
        return salty_client_send_success_t::SEND_NULL_ARGUMENT;
    }

    // Get pointer to UnboundedSender
    let sender = &*(sender_tx as *const mpsc::UnboundedSender<OutgoingMessage>) as &mpsc::UnboundedSender<OutgoingMessage>;

    // Parse message bytes into a rmpv `Value`
    let msg_slice: &[u8] = slice::from_raw_parts(msg, msg_len as usize);
    let mut msg_reader = BufReader::with_capacity(msg_slice.len(), msg_slice);
    let msg: Value = match read_value(&mut msg_reader) {
        Ok(val) => val,
        Err(e) => {
            error!("Could not send bytes: Not valid MsgPack data: {}", e);
            return salty_client_send_success_t::SEND_MESSAGE_ERROR;
        }
    };

    // Make sure that the buffer was fully consumed
    if msg_reader.bytes().next().is_some() {
        error!("Could not send bytes: Not valid msgpack data (buffer not fully consumed)");
        return salty_client_send_success_t::SEND_MESSAGE_ERROR;
    }

    match sender.unbounded_send(match msg_type {
        OutgoingMessageType::Task => OutgoingMessage::Data(msg),
        OutgoingMessageType::Application => OutgoingMessage::Application(msg),
    }) {
        Ok(_) => salty_client_send_success_t::SEND_OK,
        Err(e) => {
            error!("Sending message failed: {}", e);
            salty_client_send_success_t::SEND_ERROR
        },
    }
}

/// Send a task message through the outgoing channel.
///
/// Parameters:
///     sender_tx (`*salty_channel_sender_tx_t`, borrowed):
///         The sending end of the channel for outgoing messages.
///     msg (`*uint8_t`, borrowed):
///         Pointer to the message bytes.
///     msg_len (`uint32_t`, copied):
///         Length of the message in bytes.
#[no_mangle]
pub unsafe extern "C" fn salty_client_send_task_bytes(
    sender_tx: *const salty_channel_sender_tx_t,
    msg: *const u8,
    msg_len: u32,
) -> salty_client_send_success_t {
    salty_client_send_bytes(OutgoingMessageType::Task, sender_tx, msg, msg_len)
}

/// Send an application message through the outgoing channel.
///
/// Parameters:
///     sender_tx (`*salty_channel_sender_tx_t`, borrowed):
///         The sending end of the channel for outgoing messages.
///     msg (`*uint8_t`, borrowed):
///         Pointer to the message bytes.
///     msg_len (`uint32_t`, copied):
///         Length of the message in bytes.
#[no_mangle]
pub unsafe extern "C" fn salty_client_send_application_bytes(
    sender_tx: *const salty_channel_sender_tx_t,
    msg: *const u8,
    msg_len: u32,
) -> salty_client_send_success_t {
    salty_client_send_bytes(OutgoingMessageType::Application, sender_tx, msg, msg_len)
}

enum BlockingMode {
    BLOCKING,
    NONBLOCKING,
    TIMEOUT(Duration),
}

impl BlockingMode {
    unsafe fn from_timeout_ms(timeout_ms: *const u32) -> Self {
        if timeout_ms == ptr::null() {
            BlockingMode::BLOCKING
        } else if *timeout_ms == 0 {
            BlockingMode::NONBLOCKING
        } else {
            BlockingMode::TIMEOUT(Duration::from_millis(*timeout_ms as u64))
        }
    }

    /// Receive somedata through a channel receiver.
    ///
    /// Type arguments:
    ///
    /// - D: The type coming in through the channel receiver.
    /// - T: The return type of this function.
    /// - P: The function processing incoming data.
    /// - E: The function creating error results.
    fn recv<D, T, P, E>(
        &self,
        content_type: &str,
        rx: &mut mpsc::UnboundedReceiver<D>,
        process_data: P,
        make_error: E,
    ) -> T
    where
        P: FnOnce(D) -> T,
        E: FnOnce(salty_client_recv_success_t) -> T,
    {
        match *self {
            BlockingMode::BLOCKING => {
                match rx.wait().next() {
                    Some(Ok(data)) => process_data(data),
                    None => make_error(salty_client_recv_success_t::RECV_STREAM_ENDED),
                    Some(Err(_)) => {
                        error!("Could not receive {}", content_type);
                        make_error(salty_client_recv_success_t::RECV_ERROR)
                    },
                }
            }
            BlockingMode::NONBLOCKING => {
                let mut rx_future = rx.into_future();
                let nb_future = nonblocking::new(&mut rx_future);
                let res = nb_future.wait();
                match res {
                    Ok(Some((Some(data), _))) => process_data(data),
                    Ok(Some((None, _))) => make_error(salty_client_recv_success_t::RECV_STREAM_ENDED),
                    Ok(None) => make_error(salty_client_recv_success_t::RECV_NO_DATA),
                    Err(_) => {
                        error!("Could not receive {}", content_type);
                        make_error(salty_client_recv_success_t::RECV_ERROR)
                    },
                }
            }
            BlockingMode::TIMEOUT(duration) => {
                let timeout_future = Timer::default().sleep(duration).map_err(|_| ());
                let rx_future = rx.into_future();
                let res = rx_future.select2(timeout_future).wait();
                match res {
                    Ok(Either::A(((Some(data), _), _))) => process_data(data),
                    Ok(Either::A(((None, _), _))) => make_error(salty_client_recv_success_t::RECV_STREAM_ENDED),
                    Ok(Either::B(_)) => make_error(salty_client_recv_success_t::RECV_NO_DATA),
                    Err(_) => {
                        error!("Could not receive {}", content_type);
                        make_error(salty_client_recv_success_t::RECV_ERROR)
                    },
                }
            }
        }
    }
}


/// Receive a message from the incoming channel.
///
/// Parameters:
///     receiver_rx (`*salty_channel_receiver_rx_t`, borrowed):
///         The receiving end of the channel for incoming message events.
///     timeout_ms (`*uint32_t`, borrowed):
///         - If this is `null`, then the function call will block.
///         - If this is `0`, then the function will never block. It will either return an event
///         or `RECV_NO_DATA`.
///         - If this is a value > 0, then the specified timeout in milliseconds will be used.
///         Either an event or `RECV_NO_DATA` (in the case of a timeout) will be returned.
#[no_mangle]
pub unsafe extern "C" fn salty_client_recv_msg(
    receiver_rx: *const salty_channel_receiver_rx_t,
    timeout_ms: *const u32,
) -> salty_client_recv_msg_ret_t {
    trace!("salty_client_recv_msg");

    // Helper function: Error
    fn make_error(reason: salty_client_recv_success_t) -> salty_client_recv_msg_ret_t {
        salty_client_recv_msg_ret_t { success: reason, msg: ptr::null() }
    }

    // Helper function: Success
    fn make_ret(msg: MessageEvent) -> salty_client_recv_msg_ret_t {

        // Another helper function :)
        fn _data_or_application(val: Value, msg_type: salty_msg_type_t) -> salty_client_recv_msg_ret_t {
            // Encode msgpack bytes
            let bytes: Vec<u8> = match rmps::to_vec_named(&val) {
                Ok(bytes) => bytes,
                Err(e) => {
                    error!("Could not encode value: {}", e);
                    return make_error(salty_client_recv_success_t::RECV_ERROR);
                }
            };

            // Get pointer to bytes on heap
            let bytes_box = bytes.into_boxed_slice();
            let bytes_len = bytes_box.len();
            let bytes_ptr = Box::into_raw(bytes_box);

            // Make event struct
            let msg = salty_msg_t {
                msg_type,
                msg_bytes: bytes_ptr as *const u8,
                msg_bytes_len: bytes_len,
                close_code: 0,
            };

            // Get pointer to event on heap
            let msg_ptr = Box::into_raw(Box::new(msg));

            // TODO: Add function to free allocated memory.

            salty_client_recv_msg_ret_t {
                success: salty_client_recv_success_t::RECV_OK,
                msg: msg_ptr,
            }
        }

        match msg {
            MessageEvent::Data(val) => _data_or_application(val, salty_msg_type_t::MSG_TASK),
            MessageEvent::Application(val) => _data_or_application(val, salty_msg_type_t::MSG_APPLICATION),
            MessageEvent::Close(close_code) => {
                // Make msg struct
                let msg = salty_msg_t {
                    msg_type: salty_msg_type_t::MSG_CLOSE,
                    msg_bytes: ptr::null(),
                    msg_bytes_len: 0,
                    close_code: close_code.as_number(),
                };

                salty_client_recv_msg_ret_t {
                    success: salty_client_recv_success_t::RECV_OK,
                    msg: Box::into_raw(Box::new(msg)),
                }
            },
        }
    }

    // Null checks
    if receiver_rx.is_null() {
        error!("Receiver channel pointer is null");
        return make_error(salty_client_recv_success_t::RECV_NULL_ARGUMENT);
    }

    // Get channel receiver reference
    let rx = &mut *(receiver_rx as *mut mpsc::UnboundedReceiver<MessageEvent>)
          as &mut mpsc::UnboundedReceiver<MessageEvent>;

    // Receive message depending on blocking mode
    let blocking_mode = BlockingMode::from_timeout_ms(timeout_ms);
    blocking_mode.recv(
        // Content type
        "message",
        // Incoming channel
        rx,
        // Closure to process a new message
        |msg| make_ret(msg),
        // Closure to create an error return value
        |err| make_error(err),
    )
}

/// Free a `salty_client_recv_msg_ret_t` instance.
#[no_mangle]
pub unsafe extern "C" fn salty_client_recv_msg_ret_free(recv_ret: salty_client_recv_msg_ret_t) {
    trace!("salty_client_recv_ret_free");

    if recv_ret.msg.is_null() {
        debug!("salty_client_recv_msg_ret_free: Message is already null");
        return;
    }
    let msg = Box::from_raw(recv_ret.msg as *mut salty_msg_t);
    if !msg.msg_bytes.is_null() {
        Vec::from_raw_parts(
            msg.msg_bytes as *mut u8,
            msg.msg_bytes_len,
            msg.msg_bytes_len,
        );
    }
}

/// Receive an event from the incoming channel.
///
/// Parameters:
///     event_rx (`*salty_channel_event_rx_t`, borrowed):
///         The receiving end of the channel for incoming events.
///     timeout_ms (`*uint32_t`, borrowed):
///         - If this is `null`, then the function call will block.
///         - If this is `0`, then the function will never block. It will either return an event
///         or `RECV_NO_DATA`.
///         - If this is a value > 0, then the specified timeout in milliseconds will be used.
///         Either an event or `RECV_NO_DATA` (in the case of a timeout) will be returned.
#[no_mangle]
pub unsafe extern "C" fn salty_client_recv_event(
    event_rx: *const salty_channel_event_rx_t,
    timeout_ms: *const u32,
) -> salty_client_recv_event_ret_t {
    trace!("salty_client_recv_event");

    // Helper function: Error
    fn make_error(reason: salty_client_recv_success_t) -> salty_client_recv_event_ret_t {
        salty_client_recv_event_ret_t { success: reason, event: ptr::null() }
    }

    // Helper function: Success
    fn make_ret(event: Event) -> salty_client_recv_event_ret_t {
        // Create salty_event_t struct
        let event_t = match event {
            Event::ServerHandshakeDone(peer_connected) => salty_event_t {
                event_type: salty_event_type_t::EVENT_SERVER_HANDSHAKE_COMPLETED,
                peer_connected: peer_connected,
                peer_id: 0,
            },
            Event::PeerHandshakeDone => salty_event_t {
                event_type: salty_event_type_t::EVENT_PEER_HANDSHAKE_COMPLETED,
                peer_connected: false,
                peer_id: 0,
            },
            Event::Disconnected(peer_id) => salty_event_t {
                event_type: salty_event_type_t::EVENT_PEER_DISCONNECTED,
                peer_connected: false,
                peer_id: peer_id,
            },
        };

        salty_client_recv_event_ret_t {
            success: salty_client_recv_success_t::RECV_OK,
            event: Box::into_raw(Box::new(event_t)),
        }
    }

    // Null checks
    if event_rx.is_null() {
        error!("Event channel pointer is null");
        return make_error(salty_client_recv_success_t::RECV_NULL_ARGUMENT);
    }

    // Get channel receiver reference
    let rx = &mut *(event_rx as *mut mpsc::UnboundedReceiver<Event>)
          as &mut mpsc::UnboundedReceiver<Event>;

    // Receive message depending on blocking mode
    let blocking_mode = BlockingMode::from_timeout_ms(timeout_ms);
    blocking_mode.recv(
        // Content type
        "event",
        // Incoming channel
        rx,
        // Function to process a new message
        make_ret,
        // Function to create an error return value
        make_error,
    )
}

/// Free a `salty_client_recv_event_ret_t` instance.
#[no_mangle]
pub unsafe extern "C" fn salty_client_recv_event_ret_free(recv_ret: salty_client_recv_event_ret_t) {
    trace!("salty_client_recv_event_ret_free");
    if !recv_ret.event.is_null() {
        Box::from_raw(recv_ret.event as *mut salty_event_t);
    }
}


/// Close the connection.
///
/// The `disconnect_tx` instance is freed (as long as the pointer is not null).
///
/// Parameters:
///     disconnect_tx (`*salty_channel_disconnect_tx_t`, borrowed or moved):
///         The sending end of the channel for closing the connection.
///         This object is returned when creating a client instance.
///     close_code (`uint16_t`, copied):
///         The close code according to the SaltyRTC protocol specification.
#[no_mangle]
pub unsafe extern "C" fn salty_client_disconnect(
    disconnect_tx: *const salty_channel_disconnect_tx_t,
    close_code: u16,
) -> salty_client_disconnect_success_t {
    trace!("salty_client_disconnect");
    info!("Disconnecting with close code {}...", close_code);

    // Null pointer checks
    if disconnect_tx.is_null() {
        error!("Disconnect pointer is null");
        return salty_client_disconnect_success_t::DISCONNECT_NULL_ARGUMENT;
    }

    let disconnect_tx_box = Box::from_raw(disconnect_tx as *mut oneshot::Sender<CloseCode>);
    let code = CloseCode::from_number(close_code);
    match (*disconnect_tx_box).send(code) {
        Ok(_) => salty_client_disconnect_success_t::DISCONNECT_OK,
        Err(_) => {
            error!("Could not close connection");
            salty_client_disconnect_success_t::DISCONNECT_ERROR
        }
    }
}

enum EncryptDecryptMode {
    Encrypt,
    Decrypt,
}

/// Encrypt or decrypt raw bytes using the session keys after the handshake has been finished.
///
/// (Internal helper function.)
///
/// Parameters:
///     client (`*salty_client_t`, borrowed):
///         Pointer to a `salty_client_t` instance.
///     data (`*uint8_t`, borrowed):
///         Pointer to the data that should be en-/decrypted.
///     data_len (`size_t`, copied):
///         Number of bytes in the `data` array.
///     nonce (`*uint8_t`, borrowed):
///         Pointer to a 24 byte array containing the nonce used for en-/decryption.
unsafe fn salty_client_encrypt_decrypt_with_session_keys(
    mode: EncryptDecryptMode,
    client: *const salty_client_t,
    data: *const u8,
    data_len: size_t,
    nonce: *const u8,
) -> salty_client_encrypt_decrypt_ret_t {
    trace!("salty_client_encrypt_decrypt_with_session_keys");

    let func_name = match mode {
        EncryptDecryptMode::Encrypt => "salty_client_encrypt_with_session_keys",
        EncryptDecryptMode::Decrypt => "salty_client_decrypt_with_session_keys",
    };

    // Helper function: Error
    fn make_error(reason: salty_client_encrypt_decrypt_success_t) -> salty_client_encrypt_decrypt_ret_t {
        salty_client_encrypt_decrypt_ret_t { success: reason, bytes: ptr::null(), bytes_len: 0 }
    }

    // Null pointer checks
    if client.is_null() {
        error!("Client pointer is null");
        return make_error(salty_client_encrypt_decrypt_success_t::ENCRYPT_DECRYPT_NULL_ARGUMENT);
    }
    if data.is_null() {
        error!("Data pointer is null");
        return make_error(salty_client_encrypt_decrypt_success_t::ENCRYPT_DECRYPT_NULL_ARGUMENT);
    }
    if nonce.is_null() {
        error!("Nonce pointer is null");
        return make_error(salty_client_encrypt_decrypt_success_t::ENCRYPT_DECRYPT_NULL_ARGUMENT);
    }

    // Recreate client Arc
    let client_arc: Arc<RwLock<SaltyClient>> = Arc::from_raw(client as *const RwLock<SaltyClient>);

    // Clone Arc so that the client instance can be reused
    let client_arc_clone = client_arc.clone();
    mem::forget(client_arc);

    // Get reference to data and nonce
    let data_slice: &[u8] = slice::from_raw_parts(data, data_len as usize);
    let nonce_slice: &[u8] = slice::from_raw_parts(nonce, 24);

    // Encrypt or decrypt. Get back result with vector.
    let result = match mode {
        EncryptDecryptMode::Encrypt => client_arc_clone
            .read()
            .map_err(|e| SaltyError::Crash(format!("Could not read-lock SaltyClient: {}", e)))
            .and_then(|client| client.encrypt_raw_with_session_keys(data_slice, nonce_slice)),
        EncryptDecryptMode::Decrypt => client_arc_clone
            .read()
            .map_err(|e| SaltyError::Crash(format!("Could not read-lock SaltyClient: {}", e)))
            .and_then(|client| client.decrypt_raw_with_session_keys(data_slice, nonce_slice)),
    };
    let ciphertext = match result {
        Ok(vec) => vec,
        Err(SaltyError::NoPeer) => {
            error!("{}: Peer has not yet been established", func_name);
            return make_error(salty_client_encrypt_decrypt_success_t::ENCRYPT_DECRYPT_NO_PEER);
        },
        Err(e) => {
            error!("{}: {}", func_name, e);
            return make_error(salty_client_encrypt_decrypt_success_t::ENCRYPT_DECRYPT_ERROR);
        }
    };

    // Get pointer to bytes on heap
    let ciphertext_box = ciphertext.into_boxed_slice();
    let ciphertext_len = ciphertext_box.len();
    let ciphertext_ptr = Box::into_raw(ciphertext_box) as *const u8;

    salty_client_encrypt_decrypt_ret_t {
        success: salty_client_encrypt_decrypt_success_t::ENCRYPT_DECRYPT_OK,
        bytes: ciphertext_ptr,
        bytes_len: ciphertext_len,
    }
}

/// Encrypt raw bytes using the session keys after the handshake has been finished.
///
/// Note: The returned data must be explicitly freed with
/// `salty_client_encrypt_decrypt_free`!
///
/// Parameters:
///     client (`*salty_client_t`, borrowed):
///         Pointer to a `salty_client_t` instance.
///     data (`*uint8_t`, borrowed):
///         Pointer to the data that should be encrypted.
///     data_len (`size_t`, copied):
///         Number of bytes in the `data` array.
///     nonce (`*uint8_t`, borrowed):
///         Pointer to a 24 byte array containing the nonce used for encryption.
#[no_mangle]
pub unsafe extern "C" fn salty_client_encrypt_with_session_keys(
    client: *const salty_client_t,
    data: *const u8,
    data_len: size_t,
    nonce: *const u8,
) -> salty_client_encrypt_decrypt_ret_t {
    trace!("salty_client_encrypt_with_session_keys");
    salty_client_encrypt_decrypt_with_session_keys(
        EncryptDecryptMode::Encrypt,
        client,
        data,
        data_len,
        nonce,
    )
}

/// Decrypt raw bytes using the session keys after the handshake has been finished.
///
/// Note: The returned data must be explicitly freed with
/// `salty_client_encrypt_decrypt_free`!
///
/// Parameters:
///     client (`*salty_client_t`, borrowed):
///         Pointer to a `salty_client_t` instance.
///     data (`*uint8_t`, borrowed):
///         Pointer to the data that should be decrypted.
///     data_len (`size_t`, copied):
///         Number of bytes in the `data` array.
///     nonce (`*uint8_t`, borrowed):
///         Pointer to a 24 byte array containing the nonce used for decryption.
#[no_mangle]
pub unsafe extern "C" fn salty_client_decrypt_with_session_keys(
    client: *const salty_client_t,
    data: *const u8,
    data_len: size_t,
    nonce: *const u8,
) -> salty_client_encrypt_decrypt_ret_t {
    trace!("salty_client_decrypt_with_session_keys");
    salty_client_encrypt_decrypt_with_session_keys(
        EncryptDecryptMode::Decrypt,
        client,
        data,
        data_len,
        nonce,
    )
}

/// Free memory allocated and returned by `salty_client_encrypt_with_session_keys`
/// or `salty_client_decrypt_with_session_keys`.
///
/// Params:
///     data (`*uint8_t`, borrowed):
///         Pointer to the data that should be freed.
///     data_len (`size_t`, copied):
///         Number of bytes in the `data` array.
#[no_mangle]
pub unsafe extern "C" fn salty_client_encrypt_decrypt_free(
    data: *const u8,
    data_len: size_t,
) {
    trace!("salty_client_encrypt_decrypt_free");

    // Reclaim and forget vector
    if data.is_null() {
        warn!("salty_client_encrypt_decrypt_free: Tried to free a null pointer");
        return;
    }
    Vec::from_raw_parts(data as *mut u8, data_len as usize, data_len as usize);
}


#[cfg(test)]
mod tests {
    use super::*;
    use saltyrtc_client_ffi::{salty_keypair_new, salty_event_loop_new, salty_event_loop_get_remote};

    #[test]
    fn test_send_bytes_sender_null_ptr() {
        let msg = Box::into_raw(Box::new(vec![1, 2, 3])) as *const u8;
        let result = unsafe {
            salty_client_send_task_bytes(
                ptr::null(),
                msg,
                3,
            )
        };
        assert_eq!(result, salty_client_send_success_t::SEND_NULL_ARGUMENT);
    }

    #[test]
    fn test_send_bytes_msg_null_ptr() {
        let (tx, _rx) = mpsc::unbounded::<OutgoingMessage>();
        let tx_ptr = Box::into_raw(Box::new(tx)) as *const salty_channel_sender_tx_t;
        let result = unsafe {
            salty_client_send_task_bytes(
                tx_ptr,
                ptr::null(),
                3,
            )
        };
        assert_eq!(result, salty_client_send_success_t::SEND_NULL_ARGUMENT);
    }

    #[test]
    fn test_msgpack_decode_invalid() {
        // Create channel
        let (tx, _rx) = mpsc::unbounded::<OutgoingMessage>();
        let tx_ptr = Box::into_raw(Box::new(tx)) as *const salty_channel_sender_tx_t;

        // Create message
        // This will result in a msgpack value `Integer(1)`, the remaining two integers
        // are not part of the message anymore.
        let msg_ptr = Box::into_raw(Box::new(vec![1, 2, 3])) as *const u8;

        let result = unsafe {
            salty_client_send_task_bytes(
                tx_ptr,
                msg_ptr,
                3,
            )
        };
        assert_eq!(result, salty_client_send_success_t::SEND_MESSAGE_ERROR);
    }

    #[test]
    fn test_recv_rx_channel_null_ptr() {
        let result = unsafe { salty_client_recv_msg(ptr::null(), ptr::null()) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_NULL_ARGUMENT);
    }

    #[test]
    fn test_recv_nonblocking() {
        let (tx, rx) = mpsc::unbounded::<MessageEvent>();
        let rx_ptr = Box::into_raw(Box::new(rx)) as *const salty_channel_receiver_rx_t;

        let timeout_ptr = Box::into_raw(Box::new(0u32)) as *const u32;

        // Receive no data
        let result = unsafe { salty_client_recv_msg(rx_ptr, timeout_ptr) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_NO_DATA);

        // Send two messages
        tx.unbounded_send(MessageEvent::Data(Value::Integer(42.into()))).unwrap();
        tx.unbounded_send(MessageEvent::Application(Value::Integer(23.into()))).unwrap();
        tx.unbounded_send(MessageEvent::Close(CloseCode::from_number(3002))).unwrap();

        // Receive task data
        let result = unsafe { salty_client_recv_msg(rx_ptr, timeout_ptr) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_OK);
        assert_eq!(result.msg.is_null(), false);
        unsafe {
            let event = &*result.msg;
            assert_eq!(event.msg_type, salty_msg_type_t::MSG_TASK);
            assert_eq!(event.msg_bytes_len, 1);
            let msg_bytes = Vec::from_raw_parts(
                event.msg_bytes as *mut u8,
                event.msg_bytes_len,
                event.msg_bytes_len,
            );
            assert_eq!(msg_bytes, vec![42]);
            assert_eq!(event.close_code, 0);
        }

        // Receive application data
        let result = unsafe { salty_client_recv_msg(rx_ptr, timeout_ptr) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_OK);
        assert_eq!(result.msg.is_null(), false);
        unsafe {
            let event = &*result.msg;
            assert_eq!(event.msg_type, salty_msg_type_t::MSG_APPLICATION);
            assert_eq!(event.msg_bytes_len, 1);
            let msg_bytes = Vec::from_raw_parts(
                event.msg_bytes as *mut u8,
                event.msg_bytes_len,
                event.msg_bytes_len,
            );
            assert_eq!(msg_bytes, vec![23]);
            assert_eq!(event.close_code, 0);
        }

        // Receive close message
        let result = unsafe { salty_client_recv_msg(rx_ptr, timeout_ptr) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_OK);
        assert_eq!(result.msg.is_null(), false);
        unsafe {
            let event = &*result.msg;
            assert_eq!(event.msg_type, salty_msg_type_t::MSG_CLOSE);
            assert_eq!(event.close_code, 3002);
            assert!(event.msg_bytes.is_null());
            assert_eq!(event.msg_bytes_len, 0);
        }

        // Receive no data
        let result = unsafe { salty_client_recv_msg(rx_ptr, timeout_ptr) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_NO_DATA);

        // Drop sender
        ::std::mem::drop(tx);

        // Receive stream ended
        let result = unsafe { salty_client_recv_msg(rx_ptr, timeout_ptr) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_STREAM_ENDED);

        // Free some memory
        unsafe {
            Box::from_raw(timeout_ptr as *mut u32);
            Box::from_raw(rx_ptr as *mut salty_channel_receiver_rx_t);
        }
    }

    #[test]
    fn test_recv_timeout_thread() {
        let (tx, rx) = mpsc::unbounded::<MessageEvent>();
        let rx_ptr = Box::into_raw(Box::new(rx)) as *const salty_channel_receiver_rx_t;

        let timeout_1s_ptr = Box::into_raw(Box::new(1_000u32)) as *const u32;
        let timeout_600s_ptr = Box::into_raw(Box::new(600_000u32)) as *const u32;

        // Set up thread to post a message after 1.5 seconds
        let child = ::std::thread::spawn(move || {
            ::std::thread::sleep(Duration::from_millis(1500));
            tx.unbounded_send(MessageEvent::Close(CloseCode::from_number(3000))).unwrap();
        });

        // Wait for max 1s, but receive no data (timeout)
        let result = unsafe { salty_client_recv_msg(rx_ptr, timeout_1s_ptr) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_NO_DATA);

        // Wait again for max 1s, now data from the thread should arrive!
        let result = unsafe { salty_client_recv_msg(rx_ptr, timeout_1s_ptr) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_OK);
        assert_eq!(result.msg.is_null(), false);
        unsafe {
            let event = &*result.msg;
            assert_eq!(event.msg_type, salty_msg_type_t::MSG_CLOSE);
            assert_eq!(event.close_code, 3000);
            assert!(event.msg_bytes.is_null());
            assert_eq!(event.msg_bytes_len, 0);
        }

        // Join thread. This will result in a dropped sender.
        child.join().unwrap();

        // Immediately receive stream ended
        let result = unsafe { salty_client_recv_msg(rx_ptr, timeout_600s_ptr) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_STREAM_ENDED);

        // Free some memory
        unsafe {
            Box::from_raw(timeout_1s_ptr as *mut u32);
            Box::from_raw(timeout_600s_ptr as *mut u32);
            Box::from_raw(rx_ptr as *mut salty_channel_receiver_rx_t);
        }
    }

    #[test]
    fn test_recv_timeout_simple() {
        let (_tx, rx) = mpsc::unbounded::<MessageEvent>();
        let rx_ptr = Box::into_raw(Box::new(rx)) as *const salty_channel_receiver_rx_t;

        // Wait for max 500ms, but receive no data (timeout)
        let timeout_500ms_ptr = Box::into_raw(Box::new(500u32)) as *const u32;
        let result = unsafe { salty_client_recv_msg(rx_ptr, timeout_500ms_ptr) };
        assert_eq!(result.success, salty_client_recv_success_t::RECV_NO_DATA);

        // Free some memory
        unsafe {
            Box::from_raw(timeout_500ms_ptr as *mut u32);
            Box::from_raw(rx_ptr as *mut salty_channel_receiver_rx_t);
        }
    }

    #[test]
    fn test_free_channels() {
        let keypair = salty_keypair_new();
        let event_loop = salty_event_loop_new();
        let remote = unsafe { salty_event_loop_get_remote(event_loop) };
        let client_ret = unsafe { salty_relayed_data_initiator_new(keypair, remote, 0, ptr::null(), ptr::null()) };
        unsafe {
            salty_channel_receiver_rx_free(client_ret.receiver_rx);
            salty_channel_sender_tx_free(client_ret.sender_tx);
            salty_channel_sender_rx_free(client_ret.sender_rx);
        }
    }

    /// Using zero bytes as trusted key should fail.
    #[test]
    fn test_initiator_trusted_key_validation() {
        let keypair = salty_keypair_new();
        let event_loop = salty_event_loop_new();
        let remote = unsafe { salty_event_loop_get_remote(event_loop) };
        let zero_bytes = [0; 32];
        let zero_bytes_ptr = Box::into_raw(Box::new(zero_bytes)) as *const u8;
        let client_ret = unsafe { salty_relayed_data_initiator_new(keypair, remote, 0, zero_bytes_ptr, ptr::null()) };
        assert_eq!(client_ret.success, salty_relayed_data_success_t::TRUSTED_KEY_INVALID);
    }

    /// Using zero bytes as public key should fail.
    #[test]
    fn test_responder_public_key_validation() {
        let keypair = salty_keypair_new();
        let event_loop = salty_event_loop_new();
        let remote = unsafe { salty_event_loop_get_remote(event_loop) };
        let nonzero_bytes = [1; 32];
        let nonzero_bytes_ptr = Box::into_raw(Box::new(nonzero_bytes)) as *const u8;
        let zero_bytes = [0; 32];
        let zero_bytes_ptr = Box::into_raw(Box::new(zero_bytes)) as *const u8;
        let client_ret = unsafe { salty_relayed_data_responder_new(keypair, remote, 0, zero_bytes_ptr, nonzero_bytes_ptr, ptr::null()) };
        assert_eq!(client_ret.success, salty_relayed_data_success_t::PUBKEY_INVALID);
    }

    /// Using zero bytes as auth token should fail.
    #[test]
    fn test_responder_auth_token_validation() {
        let keypair = salty_keypair_new();
        let event_loop = salty_event_loop_new();
        let remote = unsafe { salty_event_loop_get_remote(event_loop) };
        let nonzero_bytes = [1; 32];
        let nonzero_bytes_ptr = Box::into_raw(Box::new(nonzero_bytes)) as *const u8;
        let zero_bytes = [0; 32];
        let zero_bytes_ptr = Box::into_raw(Box::new(zero_bytes)) as *const u8;
        let client_ret = unsafe { salty_relayed_data_responder_new(keypair, remote, 0, nonzero_bytes_ptr, zero_bytes_ptr, ptr::null()) };
        assert_eq!(client_ret.success, salty_relayed_data_success_t::AUTH_TOKEN_INVALID);
    }

}
