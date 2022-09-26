/**
 * C bindings for saltyrtc-task-relayed-data crate.
 * https://github.com/saltyrtc/saltyrtc-task-relayed-data-rs
 **/

#ifndef saltyrtc_task_relayed_data_bindings_h
#define saltyrtc_task_relayed_data_bindings_h

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#define LEVEL_DEBUG 1

#define LEVEL_ERROR 4

#define LEVEL_INFO 2

#define LEVEL_OFF 5

#define LEVEL_TRACE 0

#define LEVEL_WARN 3

/**
 * Result type with all potential connection error codes.
 *
 * If no error happened, the value should be `CONNECT_OK` (0).
 */
enum salty_client_connect_success_t {
  /**
   * No error.
   */
  CONNECT_OK = 0,
  /**
   * One of the arguments was a `null` pointer.
   */
  CONNECT_NULL_ARGUMENT = 1,
  /**
   * The hostname is invalid (probably not UTF-8)
   */
  CONNECT_INVALID_HOST = 2,
  /**
   * TLS related error
   */
  CONNECT_TLS_ERROR = 3,
  /**
   * Certificate related error
   */
  CONNECT_CERTIFICATE_ERROR = 4,
  /**
   * Another connection error
   */
  CONNECT_ERROR = 9,
};
typedef uint8_t salty_client_connect_success_t;

/**
 * Result type with all potential disconnection error codes.
 *
 * If no error happened, the value should be `DISCONNECT_OK` (0).
 */
enum salty_client_disconnect_success_t {
  /**
   * No error.
   */
  DISCONNECT_OK = 0,
  /**
   * One of the arguments was a `null` pointer.
   */
  DISCONNECT_NULL_ARGUMENT = 1,
  /**
   * Another connection error
   */
  DISCONNECT_ERROR = 9,
};
typedef uint8_t salty_client_disconnect_success_t;

/**
 * Result type with all potential encrypt/decrypt error codes.
 *
 * If no error happened, the value should be `ENCRYPT_DECRYPT_OK` (0).
 */
enum salty_client_encrypt_decrypt_success_t {
  /**
   * No error.
   */
  ENCRYPT_DECRYPT_OK = 0,
  /**
   * One of the arguments was a `null` pointer.
   */
  ENCRYPT_DECRYPT_NULL_ARGUMENT = 1,
  /**
   * The peer has not yet been determined.
   */
  ENCRYPT_DECRYPT_NO_PEER = 2,
  /**
   * Other error
   */
  ENCRYPT_DECRYPT_ERROR = 9,
};
typedef uint8_t salty_client_encrypt_decrypt_success_t;

/**
 * Result type with all potential init error codes.
 *
 * If no error happened, the value should be `INIT_OK` (0).
 */
enum salty_client_init_success_t {
  /**
   * No error.
   */
  INIT_OK = 0,
  /**
   * One of the arguments was a `null` pointer.
   */
  INIT_NULL_ARGUMENT = 1,
  /**
   * The hostname is invalid (probably not UTF-8)
   */
  INIT_INVALID_HOST = 2,
  /**
   * TLS related error
   */
  INIT_TLS_ERROR = 3,
  /**
   * Certificate related error
   */
  INIT_CERTIFICATE_ERROR = 4,
  /**
   * Another initialization error
   */
  INIT_ERROR = 9,
};
typedef uint8_t salty_client_init_success_t;

/**
 * Result type with all potential event receiving error codes.
 *
 * If no error happened, the value should be `RECV_OK` (0).
 */
enum salty_client_recv_success_t {
  /**
   * No error.
   */
  RECV_OK = 0,
  /**
   * One of the arguments was a `null` pointer.
   */
  RECV_NULL_ARGUMENT = 1,
  /**
   * No data is available (timeout reached).
   */
  RECV_NO_DATA = 2,
  /**
   * The stream has ended and *SHOULD NOT* be polled again.
   */
  RECV_STREAM_ENDED = 3,
  /**
   * Another receiving error
   */
  RECV_ERROR = 9,
};
typedef uint8_t salty_client_recv_success_t;

/**
 * Result type with all potential error codes.
 *
 * If no error happened, the value should be `SEND_OK` (0).
 */
enum salty_client_send_success_t {
  /**
   * No error.
   */
  SEND_OK = 0,
  /**
   * One of the arguments was a `null` pointer.
   */
  SEND_NULL_ARGUMENT = 1,
  /**
   * Sending failed because the message was invalid
   */
  SEND_MESSAGE_ERROR = 2,
  /**
   * Sending failed
   */
  SEND_ERROR = 9,
};
typedef uint8_t salty_client_send_success_t;

/**
 * Possible event types.
 */
enum salty_event_type_t {
  /**
   * A connection is being established.
   */
  EVENT_CONNECTING = 1,
  /**
   * Server handshake completed.
   */
  EVENT_SERVER_HANDSHAKE_COMPLETED = 2,
  /**
   * Peer handshake completed.
   */
  EVENT_PEER_HANDSHAKE_COMPLETED = 3,
  /**
   * A peer has disconnected from the server.
   */
  EVENT_PEER_DISCONNECTED = 4,
};
typedef uint8_t salty_event_type_t;

/**
 * Possible message types.
 */
enum salty_msg_type_t {
  /**
   * Incoming task message
   */
  MSG_TASK = 1,
  /**
   * Incoming application message.
   */
  MSG_APPLICATION = 2,
  /**
   * Incoming close message.
   */
  MSG_CLOSE = 3,
};
typedef uint8_t salty_msg_type_t;

/**
 * Result type with all potential error codes.
 *
 * If no error happened, the value should be `OK` (0).
 */
enum salty_relayed_data_success_t {
  /**
   * No error.
   */
  OK = 0,
  /**
   * One of the arguments was a `null` pointer.
   */
  NULL_ARGUMENT = 1,
  /**
   * Creation of the object failed.
   */
  CREATE_FAILED = 2,
  /**
   * The public key bytes are not valid.
   */
  PUBKEY_INVALID = 3,
  /**
   * The auth token bytes are not valid.
   */
  AUTH_TOKEN_INVALID = 4,
  /**
   * The trusted key bytes are not valid.
   */
  TRUSTED_KEY_INVALID = 5,
  /**
   * The server permanent public key bytes are not valid.
   */
  SERVER_KEY_INVALID = 6,
};
typedef uint8_t salty_relayed_data_success_t;

/**
 * The oneshot channel for closing the connection (receiving end).
 *
 * On the Rust side, this is an `oneshot::Receiver<CloseCode>`.
 */
typedef struct salty_channel_disconnect_rx_t salty_channel_disconnect_rx_t;

/**
 * The oneshot channel for closing the connection (sending end).
 *
 * On the Rust side, this is an `oneshot::Sender<CloseCode>`.
 */
typedef struct salty_channel_disconnect_tx_t salty_channel_disconnect_tx_t;

/**
 * An event channel (receiving end).
 *
 * On the Rust side, this is an `UnboundedReceiver<Event>`.
 */
typedef struct salty_channel_event_rx_t salty_channel_event_rx_t;

/**
 * An event channel (sending end).
 *
 * On the Rust side, this is an `UnboundedSender<Event>`.
 */
typedef struct salty_channel_event_tx_t salty_channel_event_tx_t;

/**
 * The channel for receiving incoming messages.
 *
 * On the Rust side, this is an `mpsc::UnboundedReceiver<MessageEvent>`.
 */
typedef struct salty_channel_receiver_rx_t salty_channel_receiver_rx_t;

/**
 * The channel for sending outgoing messages (receiving end).
 *
 * On the Rust side, this is an `mpsc::UnboundedReceiver<OutgoingMessage>`.
 */
typedef struct salty_channel_sender_rx_t salty_channel_sender_rx_t;

/**
 * The channel for sending outgoing messages (sending end).
 *
 * On the Rust side, this is an `mpsc::UnboundedSender<OutgoingMessage>`.
 */
typedef struct salty_channel_sender_tx_t salty_channel_sender_tx_t;

/**
 * A SaltyRTC client instance.
 *
 * Internally, this is a `Rc<RefCell<SaltyClient>>`.
 */
typedef struct salty_client_t salty_client_t;

/**
 * An event loop instance.
 *
 * The event loop is not thread safe.
 */
typedef struct salty_event_loop_t salty_event_loop_t;

/**
 * A handshake future. This will be passed to the `salty_client_connect`
 * function.
 *
 * On the Rust side, this is a `Box<Box<Future<Item=WsClient, Error=SaltyError>>>`.
 * The double box is used because the inner box is actually a trait object fat
 * pointer, pointing to both the data and the vtable.
 */
typedef struct salty_handshake_future_t salty_handshake_future_t;

/**
 * A key pair.
 */
typedef struct salty_keypair_t salty_keypair_t;

/**
 * A remote handle to an event loop instance.
 *
 * This type is thread safe.
 */
typedef struct salty_remote_t salty_remote_t;

/**
 * The return value when encrypting or decrypting raw data.
 *
 * Note: Before accessing `bytes`, make sure to check the `success` field for
 * errors. If an error occurred, the other fields will be `null`.
 */
typedef struct {
  salty_client_encrypt_decrypt_success_t success;
  const uint8_t *bytes;
  size_t bytes_len;
} salty_client_encrypt_decrypt_ret_t;

/**
 * The return value when initializing a connection.
 *
 * Note: Before accessing `connect_future`, make sure to check the `success`
 * field for errors. If an error occurred, the other fields will be `null`.
 */
typedef struct {
  salty_client_init_success_t success;
  const salty_handshake_future_t *handshake_future;
  const salty_channel_event_rx_t *event_rx;
  const salty_channel_event_tx_t *event_tx;
} salty_client_init_ret_t;

/**
 * An event.
 *
 * If the event type is `EVENT_SERVER_HANDSHAKE_COMPLETED`, then the
 * `peer_connected` field will contain a boolean indicating whether or not a
 * peer is already connected to the server or not. Otherwise, the field is
 * always `false` and should be ignored.
 *
 * If the event type is `EVENT_PEER_DISCONNECTED`, then the `peer_id` field
 * will contain the peer id. Otherwise, the field is `0`.
 */
typedef struct {
  salty_event_type_t event_type;
  bool peer_connected;
  uint8_t peer_id;
} salty_event_t;

/**
 * The return value when trying to receive an event.
 *
 * Note: Before accessing `event`, make sure to check the `success` field
 * for errors. If an error occurred, the `event` field will be `null`.
 */
typedef struct {
  salty_client_recv_success_t success;
  const salty_event_t *event;
} salty_client_recv_event_ret_t;

/**
 * A message event.
 *
 * If the message type is `MSG_TASK` or `MSG_APPLICATION`, then the `msg_bytes` field
 * will point to the bytes of the decrypted message. Otherwise, the field is `null`.
 *
 * If the event type is `MSG_CLOSE`, then the `close_code` field will
 * contain the close code. Otherwise, the field is `0`.
 */
typedef struct {
  salty_msg_type_t msg_type;
  const uint8_t *msg_bytes;
  uintptr_t msg_bytes_len;
  uint16_t close_code;
} salty_msg_t;

/**
 * The return value when trying to receive a message.
 *
 * Note: Before accessing `msg`, make sure to check the `success` field
 * for errors. If an error occurred, the `msg` field will be `null`.
 */
typedef struct {
  salty_client_recv_success_t success;
  const salty_msg_t *msg;
} salty_client_recv_msg_ret_t;

typedef void (*LogFunction)(uint8_t level, const char *target, const char *message);

/**
 * The return value when creating a new client instance.
 *
 * Note: Before accessing `client` or one of the channels, make sure to check
 * the `success` field for errors. If the creation of the client
 * was not successful, then the other pointers will be null.
 */
typedef struct {
  salty_relayed_data_success_t success;
  const salty_client_t *client;
  const salty_channel_receiver_rx_t *receiver_rx;
  const salty_channel_sender_tx_t *sender_tx;
  const salty_channel_sender_rx_t *sender_rx;
  const salty_channel_disconnect_tx_t *disconnect_tx;
  const salty_channel_disconnect_rx_t *disconnect_rx;
} salty_relayed_data_client_ret_t;

/**
 * Free a `salty_channel_disconnect_rx_t` instance.
 */
void salty_channel_disconnect_rx_free(const salty_channel_disconnect_rx_t *ptr);

/**
 * Free a `salty_channel_disconnect_tx_t` instance.
 */
void salty_channel_disconnect_tx_free(const salty_channel_disconnect_tx_t *ptr);

/**
 * Free a `salty_channel_event_rx_t` instance.
 */
void salty_channel_event_rx_free(const salty_channel_event_rx_t *ptr);

/**
 * Free a `salty_channel_event_tx_t` instance.
 */
void salty_channel_event_tx_free(const salty_channel_event_tx_t *ptr);

/**
 * Free a `salty_channel_receiver_rx_t` instance.
 */
void salty_channel_receiver_rx_free(const salty_channel_receiver_rx_t *ptr);

/**
 * Free a `salty_channel_sender_rx_t` instance.
 */
void salty_channel_sender_rx_free(const salty_channel_sender_rx_t *ptr);

/**
 * Free a `salty_channel_sender_tx_t` instance.
 */
void salty_channel_sender_tx_free(const salty_channel_sender_tx_t *ptr);

/**
 * Connect to the specified SaltyRTC server, do the server and peer handshake
 * and run the task loop.
 *
 * This is a blocking call. It will end once the connection has been terminated.
 * You should probably run this in a separate thread.
 *
 * Parameters:
 *     handshake_future (`*salty_handshake_future_t`, moved):
 *         Pointer to the handshake future, created with `salty_client_init`.
 *     client (`*salty_client_t`, borrowed):
 *         Pointer to a `salty_client_t` instance.
 *     event_loop (`*salty_event_loop_t`, borrowed):
 *         The event loop that is also associated with the task.
 *     event_tx (`*salty_channel_event_tx_t`, moved):
 *         The sending end of the channel for incoming events.
 *         This object is returned from `salty_client_init`.
 *     sender_rx (`*salty_channel_sender_rx_t`, moved):
 *         The receiving end of the channel for outgoing messages.
 *         This object is returned when creating a client instance.
 *     disconnect_rx (`*salty_channel_disconnect_rx_t`, moved):
 *         The receiving end of the channel for closing the connection.
 *         This object is returned when creating a client instance.
 */
salty_client_connect_success_t salty_client_connect(const salty_handshake_future_t *handshake_future,
                                                    const salty_client_t *client,
                                                    const salty_event_loop_t *event_loop,
                                                    const salty_channel_event_tx_t *event_tx,
                                                    const salty_channel_sender_rx_t *sender_rx,
                                                    const salty_channel_disconnect_rx_t *disconnect_rx);

/**
 * Decrypt raw bytes using the session keys after the handshake has been finished.
 *
 * Note: The returned data must be explicitly freed with
 * `salty_client_encrypt_decrypt_free`!
 *
 * Parameters:
 *     client (`*salty_client_t`, borrowed):
 *         Pointer to a `salty_client_t` instance.
 *     data (`*uint8_t`, borrowed):
 *         Pointer to the data that should be decrypted.
 *     data_len (`size_t`, copied):
 *         Number of bytes in the `data` array.
 *     nonce (`*uint8_t`, borrowed):
 *         Pointer to a 24 byte array containing the nonce used for decryption.
 */
salty_client_encrypt_decrypt_ret_t salty_client_decrypt_with_session_keys(const salty_client_t *client,
                                                                          const uint8_t *data,
                                                                          size_t data_len,
                                                                          const uint8_t *nonce);

/**
 * Close the connection.
 *
 * The `disconnect_tx` instance is freed (as long as the pointer is not null).
 *
 * Parameters:
 *     disconnect_tx (`*salty_channel_disconnect_tx_t`, borrowed or moved):
 *         The sending end of the channel for closing the connection.
 *         This object is returned when creating a client instance.
 *     close_code (`uint16_t`, copied):
 *         The close code according to the SaltyRTC protocol specification.
 */
salty_client_disconnect_success_t salty_client_disconnect(const salty_channel_disconnect_tx_t *disconnect_tx,
                                                          uint16_t close_code);

/**
 * Free memory allocated and returned by `salty_client_encrypt_with_session_keys`
 * or `salty_client_decrypt_with_session_keys`.
 *
 * Params:
 *     data (`*uint8_t`, borrowed):
 *         Pointer to the data that should be freed.
 *     data_len (`size_t`, copied):
 *         Number of bytes in the `data` array.
 */
void salty_client_encrypt_decrypt_free(const uint8_t *data,
                                       size_t data_len);

/**
 * Encrypt raw bytes using the session keys after the handshake has been finished.
 *
 * Note: The returned data must be explicitly freed with
 * `salty_client_encrypt_decrypt_free`!
 *
 * Parameters:
 *     client (`*salty_client_t`, borrowed):
 *         Pointer to a `salty_client_t` instance.
 *     data (`*uint8_t`, borrowed):
 *         Pointer to the data that should be encrypted.
 *     data_len (`size_t`, copied):
 *         Number of bytes in the `data` array.
 *     nonce (`*uint8_t`, borrowed):
 *         Pointer to a 24 byte array containing the nonce used for encryption.
 */
salty_client_encrypt_decrypt_ret_t salty_client_encrypt_with_session_keys(const salty_client_t *client,
                                                                          const uint8_t *data,
                                                                          size_t data_len,
                                                                          const uint8_t *nonce);

/**
 * Prepare a connection to the specified SaltyRTC server, but do not connect yet.
 *
 * Parameters:
 *     host (`*c_char`, null terminated, borrowed):
 *         Null terminated UTF-8 encoded C string containing the SaltyRTC server hostname.
 *     port (`*uint16_t`, copied):
 *         SaltyRTC server port.
 *     client (`*salty_client_t`, borrowed):
 *         Pointer to a `salty_client_t` instance.
 *     event_loop (`*salty_event_loop_t`, borrowed):
 *         The event loop that is also associated with the task.
 *     timeout_s (`uint16_t`, copied):
 *         Connection and handshake timeout in seconds. Set value to `0` for no timeout.
 *     ca_cert (`*uint8_t` or `NULL`, borrowed):
 *         Optional pointer to bytes of a DER encoded CA certificate.
 *         When no certificate is set, the OS trust chain is used.
 *     ca_cert_len (`uint32_t`, copied):
 *         When the `ca_cert` argument is not `NULL`, then this must be
 *         set to the number of certificate bytes. Otherwise, set it to 0.
 */
salty_client_init_ret_t salty_client_init(const char *host,
                                          uint16_t port,
                                          const salty_client_t *client,
                                          const salty_event_loop_t *event_loop,
                                          uint16_t timeout_s,
                                          const uint8_t *ca_cert,
                                          uint32_t ca_cert_len);

/**
 * Receive an event from the incoming channel.
 *
 * Parameters:
 *     event_rx (`*salty_channel_event_rx_t`, borrowed):
 *         The receiving end of the channel for incoming events.
 *     timeout_ms (`*uint32_t`, borrowed):
 *         - If this is `null`, then the function call will block.
 *         - If this is `0`, then the function will never block. It will either return an event
 *         or `RECV_NO_DATA`.
 *         - If this is a value > 0, then the specified timeout in milliseconds will be used.
 *         Either an event or `RECV_NO_DATA` (in the case of a timeout) will be returned.
 */
salty_client_recv_event_ret_t salty_client_recv_event(const salty_channel_event_rx_t *event_rx,
                                                      const uint32_t *timeout_ms);

/**
 * Free a `salty_client_recv_event_ret_t` instance.
 */
void salty_client_recv_event_ret_free(salty_client_recv_event_ret_t recv_ret);

/**
 * Receive a message from the incoming channel.
 *
 * Parameters:
 *     receiver_rx (`*salty_channel_receiver_rx_t`, borrowed):
 *         The receiving end of the channel for incoming message events.
 *     timeout_ms (`*uint32_t`, borrowed):
 *         - If this is `null`, then the function call will block.
 *         - If this is `0`, then the function will never block. It will either return an event
 *         or `RECV_NO_DATA`.
 *         - If this is a value > 0, then the specified timeout in milliseconds will be used.
 *         Either an event or `RECV_NO_DATA` (in the case of a timeout) will be returned.
 */
salty_client_recv_msg_ret_t salty_client_recv_msg(const salty_channel_receiver_rx_t *receiver_rx,
                                                  const uint32_t *timeout_ms);

/**
 * Free a `salty_client_recv_msg_ret_t` instance.
 */
void salty_client_recv_msg_ret_free(salty_client_recv_msg_ret_t recv_ret);

/**
 * Send an application message through the outgoing channel.
 *
 * Parameters:
 *     sender_tx (`*salty_channel_sender_tx_t`, borrowed):
 *         The sending end of the channel for outgoing messages.
 *     msg (`*uint8_t`, borrowed):
 *         Pointer to the message bytes.
 *     msg_len (`uint32_t`, copied):
 *         Length of the message in bytes.
 */
salty_client_send_success_t salty_client_send_application_bytes(const salty_channel_sender_tx_t *sender_tx,
                                                                const uint8_t *msg,
                                                                uint32_t msg_len);

/**
 * Send a task message through the outgoing channel.
 *
 * Parameters:
 *     sender_tx (`*salty_channel_sender_tx_t`, borrowed):
 *         The sending end of the channel for outgoing messages.
 *     msg (`*uint8_t`, borrowed):
 *         Pointer to the message bytes.
 *     msg_len (`uint32_t`, copied):
 *         Length of the message in bytes.
 */
salty_client_send_success_t salty_client_send_task_bytes(const salty_channel_sender_tx_t *sender_tx,
                                                         const uint8_t *msg,
                                                         uint32_t msg_len);

/**
 * Free an event loop instance.
 */
void salty_event_loop_free(const salty_event_loop_t *ptr);

/**
 * Free an event loop remote handle.
 */
void salty_event_loop_free_remote(const salty_remote_t *ptr);

/**
 * Return a remote handle from an event loop instance.
 *
 * Thread safety:
 *     The `salty_remote_t` instance may be used from any thread.
 * Ownership:
 *     The `salty_remote_t` instance must be freed through `salty_event_loop_free_remote`,
 *     or by moving it into a `salty_client_t` instance.
 * Returns:
 *     A reference to the remote handle.
 *     If the pointer passed in is `null`, an error is logged and `null` is returned.
 */
const salty_remote_t *salty_event_loop_get_remote(const salty_event_loop_t *ptr);

/**
 * Create a new event loop instance.
 *
 * In the background, this will instantiate a Tokio reactor core.
 *
 * Returns:
 *     Either a pointer to the reactor core, or `null`
 *     if creation of the event loop failed.
 *     In the case of a failure, the error will be logged.
 */
const salty_event_loop_t *salty_event_loop_new(void);

/**
 * Free a `KeyPair` instance.
 *
 * Note: If you move the `salty_keypair_t` instance into a `salty_client_t` instance,
 * you do not need to free it explicitly. It is dropped when the `salty_client_t`
 * instance is freed.
 */
void salty_keypair_free(const salty_keypair_t *ptr);

/**
 * Create a new `KeyPair` instance and return an opaque pointer to it.
 *
 * Returns:
 *     A pointer to a `salty_keypair_t`.
 */
const salty_keypair_t *salty_keypair_new(void);

/**
 * Get the private key from a `salty_keypair_t` instance.
 *
 * Returns:
 *     A null pointer if the parameter is null.
 *     Pointer to a 32 byte `uint8_t` array otherwise.
 *     Note that the lifetime of the returned pointer is tied to the keypair.
 *     If the keypair is freed, this pointer is invalidated.
 */
const uint8_t *salty_keypair_private_key(const salty_keypair_t *ptr);

/**
 * Get the public key from a `salty_keypair_t` instance.
 *
 * Returns:
 *     A null pointer if the parameter is null.
 *     Pointer to a 32 byte `uint8_t` array otherwise.
 *     Note that the lifetime of the returned pointer is tied to the keypair.
 *     If the keypair is freed, this pointer is invalidated.
 */
const uint8_t *salty_keypair_public_key(const salty_keypair_t *ptr);

/**
 * Create a new `KeyPair` instance and return an opaque pointer to it.
 *
 * Parameters:
 *     private_key (`*uint8_t`, borrowed):
 *         Pointer to a 32 byte private key.
 * Returns:
 *     A null pointer if restoring a keystore from a private key failed.
 *     A pointer to a `salty_keypair_t` otherwise.
 */
const salty_keypair_t *salty_keypair_restore(const uint8_t *ptr);

/**
 * Change the log level of the console logger.
 *
 * Parameters:
 *     level (uint8_t, copied):
 *         The log level, must be in the range 0 (TRACE) to 5 (OFF).
 *         See `LEVEL_*` constants for reference.
 * Returns:
 *     A boolean indicating whether logging was updated successfully.
 *     If updating the logger failed, an error message will be written to stdout.
 */
bool salty_log_change_level_console(uint8_t level);

/**
 * Initialize logging with a custom callback function that will be called for every log.
 *
 * Parameters:
 *     callback:
 *         Pointer to a function with the signature
 *         `(uint8_t level, char* target, char* message)`.
 *     level (uint8_t, copied):
 *         The log level, must be in the range 0 (TRACE) to 5 (OFF).
 *         See `LEVEL_*` constants for reference.
 * Returns:
 *     A boolean indicating whether logging was setup successfully.
 *     If setting up the logger failed, an error message will be written to stdout.
 */
bool salty_log_init_callback(LogFunction callback,
                             uint8_t level);

/**
 * Initialize logging to stdout with log messages up to the specified log level.
 *
 * Parameters:
 *     level (uint8_t, copied):
 *         The log level, must be in the range 0 (TRACE) to 5 (OFF).
 *         See `LEVEL_*` constants for reference.
 * Returns:
 *     A boolean indicating whether logging was setup successfully.
 *     If setting up the logger failed, an error message will be written to stdout.
 */
bool salty_log_init_console(uint8_t level);

/**
 * Get a pointer to the auth token bytes from a `salty_client_t` instance.
 *
 * Ownership:
 *     The memory is still owned by the `salty_client_t` instance.
 *     Do not reuse the reference after the `salty_client_t` instance has been freed!
 * Returns:
 *     A null pointer if the parameter is null, if no auth token is set on the client
 *     or if the arc cannot be borrowed.
 *     Pointer to a 32 byte `uint8_t` array otherwise.
 */
const uint8_t *salty_relayed_data_client_auth_token(const salty_client_t *ptr);

/**
 * Free a SaltyRTC client with the Relayed Data task.
 */
void salty_relayed_data_client_free(const salty_client_t *ptr);

/**
 * Initialize a new SaltyRTC client as initiator with the Relayed Data task.
 *
 * Parameters:
 *     keypair (`*salty_keypair_t`, moved):
 *         Pointer to a key pair.
 *     remote (`*salty_remote_t`, moved):
 *         Pointer to an event loop remote handle.
 *     ping_interval_seconds (`uint32_t`, copied):
 *         Request that the server sends a WebSocket ping message at the specified interval.
 *         Set this argument to `0` to disable ping messages.
 *     trusted_responder_key (`*uint8_t` or `null`, borrowed):
 *         The trusted responder public key. If set, this must be a pointer to a 32 byte
 *         `uint8_t` array. Set this to null when not restoring a trusted session.
 *     server_public_permanent_key (`*uint8_t` or `null`, borrowed):
 *         The server public permanent key. If set, this must be a pointer to a 32 byte
 *         `uint8_t` array. Set this to null to not validate the server public key.
 * Returns:
 *     A `salty_relayed_data_client_ret_t` struct.
 */
salty_relayed_data_client_ret_t salty_relayed_data_initiator_new(const salty_keypair_t *keypair,
                                                                 const salty_remote_t *remote,
                                                                 uint32_t ping_interval_seconds,
                                                                 const uint8_t *trusted_responder_key,
                                                                 const uint8_t *server_public_permanent_key);

/**
 * Initialize a new SaltyRTC client as responder with the Relayed Data task.
 *
 * Parameters:
 *     keypair (`*salty_keypair_t`, moved):
 *         Pointer to a key pair.
 *     remote (`*salty_remote_t`, moved):
 *         Pointer to an event loop remote handle.
 *     ping_interval_seconds (`uint32_t`, copied):
 *         Request that the server sends a WebSocket ping message at the specified interval.
 *         Set this argument to `0` to disable ping messages.
 *     initiator_pubkey (`*uint8_t`, borrowed):
 *         Public key of the initiator. A 32 byte `uint8_t` array.
 *     auth_token (`*uint8_t` or `null`, borrowed):
 *         One-time auth token from the initiator. If set, this must be a pointer
 *         to a 32 byte `uint8_t` array. Set this to `null` when restoring a trusted session.
 *     server_public_permanent_key (`*uint8_t` or `null`, borrowed):
 *         The server public permanent key. If set, this must be a pointer to a 32 byte
 *         `uint8_t` array. Set this to null to not validate the server public key.
 * Returns:
 *     A `salty_relayed_data_client_ret_t` struct.
 */
salty_relayed_data_client_ret_t salty_relayed_data_responder_new(const salty_keypair_t *keypair,
                                                                 const salty_remote_t *remote,
                                                                 uint32_t ping_interval_seconds,
                                                                 const uint8_t *initiator_pubkey,
                                                                 const uint8_t *auth_token,
                                                                 const uint8_t *server_public_permanent_key);

#endif /* saltyrtc_task_relayed_data_bindings_h */
