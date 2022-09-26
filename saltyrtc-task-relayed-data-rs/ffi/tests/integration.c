/**
 * C integration test.
 */
#include <pthread.h>
#include <semaphore.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "../saltyrtc_task_relayed_data_ffi.h"


// Function prototypes
void drain_events(const salty_channel_event_rx_t *event_rx, char *role);
void *connect_initiator(void *threadarg);
void *connect_responder(void *threadarg);

// Statics
static sem_t auth_token_set;
static sem_t initiator_channels_ready;
static sem_t responder_channels_ready;
static uint8_t *auth_token = NULL;
static const salty_channel_sender_tx_t *initiator_sender = NULL;
static const salty_channel_sender_tx_t *responder_sender = NULL;
static const salty_channel_receiver_rx_t *initiator_receiver = NULL;
static const salty_channel_receiver_rx_t *responder_receiver = NULL;
static const salty_channel_disconnect_tx_t *initiator_disconnect = NULL;
static const salty_channel_disconnect_tx_t *responder_disconnect = NULL;


/**
 * Drain events from the receiving end of the event channel.
 */
void drain_events(const salty_channel_event_rx_t *event_rx, char *role) {
    uint32_t timeout_ms = 10;
    bool stop = false;
    while (!stop) {
        salty_client_recv_event_ret_t event_ret = salty_client_recv_event(event_rx, &timeout_ms);
        printf("    %s EVENT:", role);
        switch (event_ret.success) {
            case RECV_OK:
                break;
            case RECV_NULL_ARGUMENT:
                printf(" error (null argument)");
                stop = true; break;
            case RECV_NO_DATA:
                printf(" error (no data)");
                stop = true; break;
            case RECV_STREAM_ENDED:
                printf(" event stream ended");
                stop = true; break;
            case RECV_ERROR:
                printf(" unknown error");
                stop = true; break;
            default:
                printf(" unexpected error");
                stop = true; break;
        }
        if (event_ret.success == RECV_OK) {
            switch (event_ret.event->event_type) {
                case EVENT_CONNECTING:
                    printf(" connecting\n");
                    break;
                case EVENT_SERVER_HANDSHAKE_COMPLETED:
                    printf(" server handshake completed (");
                    if (event_ret.event->peer_connected) {
                        printf("peer connected");
                    } else {
                        printf("peer not connected");
                    }
                    printf(")\n");
                    break;
                case EVENT_PEER_HANDSHAKE_COMPLETED:
                    printf(" peer handshake completed\n");
                    break;
                case EVENT_PEER_DISCONNECTED:
                    printf(" peer %d disconnected\n", event_ret.event->peer_id);
                    break;
            }
        } else {
            printf("\n");
        }
        salty_client_recv_event_ret_free(event_ret);
    }
}


/**
 * Struct used to pass data from the main thread to the client threads.
 */
struct thread_data {
    uint32_t interval_seconds;
    uint16_t timeout_seconds;
    const salty_keypair_t *keypair;
    const uint8_t *initiator_pubkey;
    const uint8_t *ca_cert;
    long ca_cert_len;
};

/**
 * Client thread for the initiator.
 */
void *connect_initiator(void *threadarg) {
    struct thread_data *data = (struct thread_data *) threadarg;
    printf("  THREAD: Started initiator thread\n");

    printf("    INITIATOR: Creating event loop\n");
    const salty_event_loop_t *loop = salty_event_loop_new();

    printf("    INITIATOR: Getting event loop remote handle\n");
    const salty_remote_t *remote = salty_event_loop_get_remote(loop);
    const salty_remote_t *unused_remote = salty_event_loop_get_remote(loop);

    printf("    INITIATOR: Creating client instance\n");
    salty_relayed_data_client_ret_t client_ret = salty_relayed_data_initiator_new(
        data->keypair,
        remote,
        data->interval_seconds,
        NULL,
        NULL
    );
    if (client_ret.success != OK) {
        printf("    INITIATOR ERROR: Could not create client: %d", client_ret.success);
        pthread_exit(NULL);
    }

    initiator_sender = client_ret.sender_tx;
    initiator_receiver = client_ret.receiver_rx;
    initiator_disconnect = client_ret.disconnect_tx;
    printf("    INITIATOR: Notifying main thread that the channels are ready\n");
    sem_post(&initiator_channels_ready);

    printf("    INITIATOR: Copying auth token to static variable\n");
    auth_token = malloc(32 * sizeof(uint8_t));
    if (auth_token == NULL) {
        printf("      INITIATOR ERROR: Could not allocate memory for auth token");
        pthread_exit(NULL);
    }
    const uint8_t *auth_token_ref = salty_relayed_data_client_auth_token(client_ret.client);
    memcpy(auth_token, auth_token_ref, 32 * sizeof(uint8_t));

    printf("    INITIATOR: Notifying responder that the auth token is ready\n");
    sem_post(&auth_token_set);

    printf("    INITIATOR: Initializing\n");
    salty_client_init_ret_t init_ret = salty_client_init(
        // Host, port
        "localhost",
        8765,
        // Client
        client_ret.client,
        // Event loop
        loop,
        // Timeout seconds
        data->timeout_seconds,
        // CA certificate
        data->ca_cert,
        (uint32_t)data->ca_cert_len
    );
    if (init_ret.success != INIT_OK) {
        printf("      INITIATOR ERROR: Could not initialize connection: %d", init_ret.success);
        pthread_exit(NULL);
    }

    printf("    INITIATOR: Connecting\n");
    salty_client_connect_success_t connect_success = salty_client_connect(
        // Handshake future
        init_ret.handshake_future,
        // Client
        client_ret.client,
        // Event loop
        loop,
        // Event channel, sending end
        init_ret.event_tx,
        // Sender channel, receiving end
        client_ret.sender_rx,
        // Disconnect channel, receiving end
        client_ret.disconnect_rx
    );

    drain_events(init_ret.event_rx, "INITIATOR");

    printf("    INITIATOR: Connection ended with exit code %d\n", connect_success);
    salty_client_connect_success_t* connect_success_copy = malloc(sizeof(connect_success));
    if (connect_success_copy == NULL) {
        printf("      INITIATOR ERROR: Could not malloc %ld bytes\n", sizeof(connect_success));
        pthread_exit(NULL);
    }
    memcpy(connect_success_copy, &connect_success, sizeof(connect_success));

    printf("    INITIATOR: Freeing unused event loop remote handle\n");
    salty_event_loop_free_remote(unused_remote);

    printf("    INITIATOR: Freeing client instance\n");
    salty_relayed_data_client_free(client_ret.client);

    printf("    INITIATOR: Freeing channel instances\n");
    salty_channel_receiver_rx_free(client_ret.receiver_rx);
    salty_channel_sender_tx_free(client_ret.sender_tx);
    salty_channel_event_rx_free(init_ret.event_rx);

    printf("  INITIATOR: Freeing event loop\n");
    salty_event_loop_free(loop);

    printf("  THREAD: Stopping initiator thread\n");
    pthread_exit((void *)connect_success_copy);
}

/**
 * Client thread for the responder.
 */
void *connect_responder(void *threadarg) {
    struct thread_data *data = (struct thread_data *) threadarg;
    printf("  THREAD: Started responder thread\n");

    printf("    RESPONDER: Creating event loop\n");
    const salty_event_loop_t *loop = salty_event_loop_new();

    printf("    RESPONDER: Getting event loop remote handle\n");
    const salty_remote_t *remote = salty_event_loop_get_remote(loop);

    printf("    RESPONDER: Waiting for auth token semaphore...\n");
    sem_wait(&auth_token_set);

    printf("    RESPONDER: Creating client instance\n");
    salty_relayed_data_client_ret_t client_ret = salty_relayed_data_responder_new(
        data->keypair,
        remote,
        data->interval_seconds,
        data->initiator_pubkey,
        auth_token,
        NULL
    );
    if (client_ret.success != OK) {
        printf("      RESPONDER ERROR: Could not create client: %d", client_ret.success);
        pthread_exit(NULL);
    }

    responder_sender = client_ret.sender_tx;
    responder_receiver = client_ret.receiver_rx;
    responder_disconnect = client_ret.disconnect_tx;
    printf("    RESPONDER: Notifying main thread that the channels are ready\n");
    sem_post(&responder_channels_ready);

    printf("    RESPONDER: Initializing\n");
    salty_client_init_ret_t init_ret = salty_client_init(
        // Host, port
        "localhost",
        8765,
        // Client
        client_ret.client,
        // Event loop
        loop,
        // Timeout seconds
        data->timeout_seconds,
        // CA certificate
        data->ca_cert,
        (uint32_t)data->ca_cert_len
    );
    if (init_ret.success != INIT_OK) {
        printf("      RESPONDER ERROR: Could not initialize connection: %d", init_ret.success);
        pthread_exit(NULL);
    }

    printf("    RESPONDER: Connecting\n");
    salty_client_connect_success_t connect_success = salty_client_connect(
        // Handshake future
        init_ret.handshake_future,
        // Client
        client_ret.client,
        // Event loop
        loop,
        // Event channel, sending end
        init_ret.event_tx,
        // Sender channel, receiving end
        client_ret.sender_rx,
        // Disconnect channel, receiving end
        client_ret.disconnect_rx
    );

    drain_events(init_ret.event_rx, "RESPONDER");

    printf("    RESPONDER: Connection ended with exit code %d\n", connect_success);
    salty_client_connect_success_t* connect_success_copy = malloc(sizeof(connect_success));
    if (connect_success_copy == NULL) {
        printf("      RESPONDER ERROR: Could not malloc %ld bytes\n", sizeof(connect_success));
        pthread_exit(NULL);
    }
    memcpy(connect_success_copy, &connect_success, sizeof(connect_success));

    printf("    RESPONDER: Freeing client instance\n");
    salty_relayed_data_client_free(client_ret.client);

    printf("    RESPONDER: Freeing channel instances\n");
    salty_channel_receiver_rx_free(client_ret.receiver_rx);
    salty_channel_sender_tx_free(client_ret.sender_tx);
    salty_channel_event_rx_free(init_ret.event_rx);

    printf("  RESPONDER: Freeing event loop\n");
    salty_event_loop_free(loop);

    printf("  THREAD: Stopping responder thread\n");
    pthread_exit((void *)connect_success_copy);
}

/**
 * Logger callback function.
 */
static void log_callback(uint8_t level, const char *target, const char *message) {
    printf("****** [%d] %s: %s\n", level, target, message);
}

/**
 * Main program.
 */
int main(int argc, char *argv[]) {
    // Parse arguments
    int opt;
    enum { LOGGER_CONSOLE, LOGGER_CALLBACK } logger = LOGGER_CONSOLE;
    while ((opt = getopt(argc, argv, "l:")) != -1) {
        switch (opt) {
            case 'l':
                if (strcmp(optarg, "console") == 0) {
                    logger = LOGGER_CONSOLE;
                    break;
                }
                if (strcmp(optarg, "callback") == 0) {
                    logger = LOGGER_CALLBACK;
                    break;
                }
                fprintf(stderr, "Invalid logger mode: %s\n", optarg);
                return EXIT_FAILURE;
            default:
                fprintf(stderr, "Usage: %s [-l LOGGER_MODE]\n\n", argv[0]);
                fprintf(stderr, "Note: The logger mode may be either 'console' or 'callback'.\n");
                fprintf(stderr, "      The default value is 'console'.\n");
                return EXIT_FAILURE;
        }
    }
    printf("Logger: %d\n", logger);

    printf("START C TEST\n");

    printf("  Reading DER formatted test CA certificate\n");

    // Open file
    const char *const ca_cert_name = "saltyrtc.der";
    FILE *fd = fopen(ca_cert_name, "rb");
    if (fd == NULL) {
        printf("    ERROR: Could not open `%s`\n", ca_cert_name);
        return EXIT_FAILURE;
    }

    // Get file size
    if (fseek(fd, 0, SEEK_END) != 0) {
        printf("    ERROR: Could not fseek `%s`\n", ca_cert_name);
        return EXIT_FAILURE;
    }
    long ca_cert_len = ftell(fd);
    if (ca_cert_len < 0) {
        printf("    ERROR: Could not ftell `%s`\n", ca_cert_name);
        return EXIT_FAILURE;
    } else if (ca_cert_len >= (1L << 32)) {
        printf("    ERROR: ca_cert_len is larger than 2**32\n");
        return EXIT_FAILURE;
    }
    if (fseek(fd, 0, SEEK_SET) != 0) {
        printf("    ERROR: Could not fseek `%s`\n", ca_cert_name);
        return EXIT_FAILURE;
    }

    // Prepare buffer
    uint8_t *ca_cert = malloc((size_t)ca_cert_len);
    if (ca_cert == NULL) {
        printf("    ERROR: Could not malloc %ld bytes\n", ca_cert_len);
        return EXIT_FAILURE;
    }
    size_t read_bytes = fread(ca_cert, (size_t)ca_cert_len, 1, fd);
    if (read_bytes != 1) {
        printf("    ERROR: Could not read file\n");
        return EXIT_FAILURE;
    }
    if (fclose(fd) != 0) printf("Warning: Closing ca cert file descriptor failed");

    if (logger == LOGGER_CONSOLE) {
        printf("  Initializing console logger (level DEBUG)\n");
        if (!salty_log_init_console(LEVEL_DEBUG)) {
            return EXIT_FAILURE;
        }
        printf("  Updating logger (level WARN)\n");
        if (!salty_log_change_level_console(LEVEL_WARN)) {
            return EXIT_FAILURE;
        }
    } else if (logger == LOGGER_CALLBACK) {
        printf("  Initializing callback logger (level DEBUG)\n");
        if (!salty_log_init_callback(log_callback, LEVEL_DEBUG)) {
            return EXIT_FAILURE;
        }
    }

    printf("  Creating key pairs\n");
    const salty_keypair_t *i_keypair = salty_keypair_new();
    const salty_keypair_t *r_keypair = salty_keypair_new();
    const salty_keypair_t *unused_keypair = salty_keypair_new();

    printf("  Restoring keypair from existing key\n");
    uint8_t *private_key_ptr = malloc(32);
    if (private_key_ptr == NULL) {
        printf("    ERROR: Could not malloc 32 bytes\n");
        return EXIT_FAILURE;
    }
    memset(private_key_ptr, 42, 32);
    const salty_keypair_t *restored_keypair = salty_keypair_restore(private_key_ptr);

    printf("  Extracting private key of existing keypair\n");
    const uint8_t *extracted_private_key = salty_keypair_private_key(restored_keypair);
    if (memcmp(private_key_ptr, extracted_private_key, 32) != 0) {
        printf("    ERROR: Extracted private key does not match original private key\n");
        free(private_key_ptr);
        return EXIT_FAILURE;
    }
    free(private_key_ptr);

    printf("  Copying public key from initiator\n");
    uint8_t *i_pubkey = malloc(32 * sizeof(uint8_t));
    if (i_pubkey == NULL) {
        printf("    ERROR: Could not allocate memory for public key");
        return EXIT_FAILURE;
    }
    const uint8_t *i_pubkey_ref = salty_keypair_public_key(i_keypair);
    memcpy(i_pubkey, i_pubkey_ref, 32 * sizeof(uint8_t));

    printf("  Initiating semaphores\n");
    sem_init(&auth_token_set, 0, 0);
    sem_init(&initiator_channels_ready, 0, 0);
    sem_init(&responder_channels_ready, 0, 0);

    // Start initiator thread
    pthread_t i_thread;
    struct thread_data i_data = {
        .interval_seconds = 0,
        .timeout_seconds = 5,
        .keypair = i_keypair,
        .initiator_pubkey = NULL,
        .ca_cert = ca_cert,
        .ca_cert_len = ca_cert_len
    };
    pthread_create(&i_thread, NULL, connect_initiator, (void*)&i_data);

    // Start responder thread
    pthread_t r_thread;
    struct thread_data r_data = {
        .interval_seconds = 0,
        .timeout_seconds = 5,
        .keypair = r_keypair,
        .initiator_pubkey = i_pubkey,
        .ca_cert = ca_cert,
        .ca_cert_len = ca_cert_len
    };
    pthread_create(&r_thread, NULL, connect_responder, (void*)&r_data);

    // Waiting for connection event
    printf("  Waiting for initiator tx channel...\n");
    sem_wait(&initiator_channels_ready);
    printf("  Waiting for responder tx channel...\n");
    sem_wait(&responder_channels_ready);
    printf("  Both outgoing channels are ready\n");

    // Send message
    printf("  Sending message from initiator to responder\n");
    const uint8_t msg[] = { 0x93, 0x01, 0x02, 0x03 };
    if (SEND_OK != salty_client_send_task_bytes(initiator_sender, msg, 4)) {
        printf("  ERROR: Sending message from initiator to responder failed\n");
        return EXIT_FAILURE;
    }

    // Receive message
    printf("  Waiting for message to arrive...\n");
    uint32_t timeout_ms = 10000;
    const salty_client_recv_msg_ret_t recv_msg_ret = salty_client_recv_msg(responder_receiver, &timeout_ms);
    switch (recv_msg_ret.success) {
        case RECV_OK:
            printf("  OK: Message (%lu bytes) from initiator arrived!\n", recv_msg_ret.msg->msg_bytes_len);
            if (recv_msg_ret.msg->msg_bytes_len != 4 ||
                recv_msg_ret.msg->msg_bytes[0] != 0x93 ||
                recv_msg_ret.msg->msg_bytes[1] != 0x01 ||
                recv_msg_ret.msg->msg_bytes[2] != 0x02 ||
                recv_msg_ret.msg->msg_bytes[3] != 0x03) {
                printf("  ERROR: Invalid message received\n");
                return EXIT_FAILURE;
            } else {
                printf("  OK: Message is valid!\n");
            }
            break;
        case RECV_NO_DATA:
            printf("  ERROR: Waiting for message timed out!\n");
            return EXIT_FAILURE;
        case RECV_STREAM_ENDED:
            printf("  ERROR: The incoming event stream has ended!\n");
            return EXIT_FAILURE;
        default:
            printf("  ERROR: Error while waiting for incoming message\n");
            return EXIT_FAILURE;
    }
    printf("  Freeing received event\n");
    salty_client_recv_msg_ret_free(recv_msg_ret);

    // Disconnect
    printf("  Disconnecting initiator\n");
    salty_client_disconnect(initiator_disconnect, 1001);
    printf("  Disconnecting responder\n");
    salty_client_disconnect(responder_disconnect, 1001);

    // Joining client threads
    printf("  Waiting for client threads to terminate...\n");
    salty_client_connect_success_t *i_success;
    salty_client_connect_success_t *r_success;
    pthread_join(i_thread, (void*)&i_success);
    pthread_join(r_thread, (void*)&r_success);

    bool success = true;
    if (*i_success != CONNECT_OK) {
        printf("ERROR: Connecting initiator was not successful\n");
        success = false;
    } else {
        printf("OK: Connection initiator was successful\n");
    }
    free(i_success);
    if (*r_success != CONNECT_OK) {
        printf("ERROR: Connecting responder was not successful\n");
        success = false;
    } else {
        printf("OK: Connection responder was successful\n");
    }
    free(r_success);
    if (!success) {
        return EXIT_FAILURE;
    }

    printf("CLEANUP\n");

    printf("  Freeing CA cert bytes\n");
    free(ca_cert);

    printf("  Freeing public key copy\n");
    free(i_pubkey);

    printf("  Freeing unused keypairs\n");
    salty_keypair_free(unused_keypair);
    salty_keypair_free(restored_keypair);

    printf("  Destroying semaphores\n");
    sem_destroy(&auth_token_set);
    sem_destroy(&initiator_channels_ready);
    sem_destroy(&responder_channels_ready);

    printf("END C TEST\n");

    // Close stdout / stderr to please valgrind
    if (fclose(stdin) != 0) printf("Warning: Closing stdin failed");
    if (fclose(stdout) != 0) printf("Warning: Closing stdout failed");
    if (fclose(stderr) != 0) printf("Warning: Closing stderr failed");

    return EXIT_SUCCESS;
}
