/**
 * A C test to ensure that disconnecting results
 * in the connection thread being stopped.
 */
#include <pthread.h>
#include <semaphore.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../saltyrtc_task_relayed_data_ffi.h"


// Function prototypes
bool wait_for_server_handshake_completion(uint32_t timeout_ms);
void *connect_initiator(void *threadarg);

// Statics
static sem_t initialized;
static const salty_channel_event_rx_t *event_rx = NULL;
static const salty_channel_disconnect_tx_t *disconnect_tx = NULL;

/**
 * Drain events from the receiving end of the event channel.
 */
bool wait_for_server_handshake_completion(uint32_t timeout_ms) {
    bool stop = false;
    bool done = false;
    while (!stop && !done) {
        salty_client_recv_event_ret_t event_ret = salty_client_recv_event(event_rx, &timeout_ms);
        printf("    EVENT:");
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
                    done = true;
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
    return done;
}


/**
 * Client thread for the initiator.
 */
void *connect_initiator(void *threadarg) {
    if (threadarg == NULL) { /* get rid of unused variable warning */ }

    printf("  Reading DER formatted test CA certificate\n");

    // Open file
    const char *const ca_cert_name = "saltyrtc.der";
    FILE *fd = fopen(ca_cert_name, "rb");
    if (fd == NULL) {
        printf("    ERROR: Could not open `%s`\n", ca_cert_name);
        pthread_exit((void *)1);
    }

    // Get file size
    if (fseek(fd, 0, SEEK_END) != 0) {
        printf("    ERROR: Could not fseek `%s`\n", ca_cert_name);
        pthread_exit((void *)1);
    }
    long ca_cert_len = ftell(fd);
    if (ca_cert_len < 0) {
        printf("    ERROR: Could not ftell `%s`\n", ca_cert_name);
        pthread_exit((void *)1);
    } else if (ca_cert_len >= (1L << 32)) {
        printf("    ERROR: ca_cert_len is larger than 2**32\n");
        pthread_exit((void *)1);
    }
    if (fseek(fd, 0, SEEK_SET) != 0) {
        printf("    ERROR: Could not fseek `%s`\n", ca_cert_name);
        pthread_exit((void *)1);
    }

    // Prepare buffer
    uint8_t *ca_cert = malloc((size_t)ca_cert_len);
    if (ca_cert == NULL) {
        printf("    ERROR: Could not malloc %ld bytes\n", ca_cert_len);
        pthread_exit((void *)1);
    }
    size_t read_bytes = fread(ca_cert, (size_t)ca_cert_len, 1, fd);
    if (read_bytes != 1) {
        printf("    ERROR: Could not read file\n");
        pthread_exit((void *)1);
    }
    if (fclose(fd) != 0) { printf("Warning: Closing ca cert file descriptor failed"); }

    printf("  Initializing console logger (level WARN)\n");
    if (!salty_log_init_console(LEVEL_WARN)) {
        pthread_exit((void *)1);
    }

    printf("  Creating key pair\n");
    const salty_keypair_t *keypair = salty_keypair_new();

    printf("  Creating event loop\n");
    const salty_event_loop_t *loop = salty_event_loop_new();

    printf("  Getting event loop remote handle\n");
    const salty_remote_t *remote = salty_event_loop_get_remote(loop);

    printf("  Creating client instance\n");
    salty_relayed_data_client_ret_t client_ret = salty_relayed_data_initiator_new(
        keypair,
        remote,
        0, // interval seconds
        NULL,
        NULL
    );
    if (client_ret.success != OK) {
        printf("  ERROR: Could not create client: %d", client_ret.success);
        pthread_exit((void *)1);
    }

    printf("  Initializing\n");
    salty_client_init_ret_t init_ret = salty_client_init(
        // Host, port
        "localhost",
        8765,
        // Client
        client_ret.client,
        // Event loop
        loop,
        // Timeout seconds
        5,
        // CA certificate
        ca_cert,
        (uint32_t)ca_cert_len
    );
    if (init_ret.success != INIT_OK) {
        printf("    ERROR: Could not initialize connection: %d", init_ret.success);
        pthread_exit((void *)1);
    }

    // Assign event_rx to static
    event_rx = init_ret.event_rx;
    disconnect_tx = client_ret.disconnect_tx;
    sem_post(&initialized);

    printf("  Connecting...\n");
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

    printf("    Connection ended with exit code %d\n", connect_success);

    printf("  Freeing client instance\n");
    salty_relayed_data_client_free(client_ret.client);

    printf("  Freeing channel instances\n");
    salty_channel_receiver_rx_free(client_ret.receiver_rx);
    salty_channel_sender_tx_free(client_ret.sender_tx);
    salty_channel_event_rx_free(init_ret.event_rx);

    printf("  Freeing event loop\n");
    salty_event_loop_free(loop);

    printf("  Freeing CA cert bytes\n");
    free(ca_cert);

    pthread_exit((void *)0);
}


/**
 * Main program.
 */
int main() {
    printf("START C TEST\n");

    printf("  START THREAD\n");
    pthread_t thread;
    pthread_create(&thread, NULL, connect_initiator, NULL);

    printf("  WAITING FOR INIT\n");
    sem_wait(&initialized);

    printf("  WAITING FOR SERVER HANDSHAKE COMPLETION\n");
    bool success = wait_for_server_handshake_completion(5000);
    if (!success) {
        printf("  Waiting for server handshake completion failed!");
        return EXIT_FAILURE;
    }
    printf("    SERVER HANDSHAKE DONE\n");
    printf("  DISCONNECT\n");
    salty_client_disconnect_success_t disconnect_success = salty_client_disconnect(disconnect_tx, 1001);
    if (disconnect_success != DISCONNECT_OK) {
        printf("  Disconnect failed with code %d\n", disconnect_success);
        return EXIT_FAILURE;
    }

    printf("  JOIN THREAD\n");
    int *result;
    pthread_join(thread, (void*)&result);
    if (result != 0) {
        printf("  Thread failed\n");
        return EXIT_FAILURE;
    }

    printf("END C TEST\n");

    // Close stdout / stderr to please valgrind
    if (fclose(stdin) != 0) { printf("Warning: Closing stdin failed"); }
    if (fclose(stdout) != 0) { printf("Warning: Closing stdout failed"); }
    if (fclose(stderr) != 0) { printf("Warning: Closing stderr failed"); }

    return EXIT_SUCCESS;
}
