//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

#include <CommonCrypto/CommonDigest.h>

#import "ServerConnector.h"
#import "NSString+Hex.h"
#import "BoxedMessage.h"
#import "MyIdentityStore.h"
#import "ProtocolDefines.h"
#import "Reachability.h"
#import "MessageQueue.h"
#import "MessageProcessorProxy.h"
#import "Utils.h"
#import "ContactStore.h"
#import "UserSettings.h"
#import "BundleUtil.h"
#import "AppGroup.h"
#import "LicenseStore.h"
#import "PushPayloadDecryptor.h"
#import "ValidationLogger.h"
#import "GCDAsyncSocketFactory.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
#define LOG_KEY_INFO    0

@implementation ServerConnector {
    NSData *clientTempKeyPub;
    NSData *clientTempKeySec;
    time_t clientTempKeyGenTime;
    NSData *clientCookie;
    
    NSData *serverCookie;
    NSData *serverTempKeyPub;
    
    NSString *serverNamePrefix;
    NSString *serverNamePrefixv6;
    NSString *serverNameSuffix;
    NSArray *serverPorts;
    int curServerPortIndex;
    NSData *chosenServerKeyPub;
    NSData *serverKeyPub;
    NSData *serverAltKeyPub;
    
    uint64_t serverNonce;
    uint64_t clientNonce;
    dispatch_queue_t queue;
    dispatch_source_t keepalive_timer;
    NSCondition *disconnectCondition;
    GCDAsyncSocket *socket;
    int reconnectAttempts;
    
    enum ConnectionState connectionState;
    BOOL autoReconnect;
    CFTimeInterval lastRead;
    NSDate *lastErrorDisplay;

    CFTimeInterval lastEchoSendTime;
    uint64_t lastSentEchoSeq;
    uint64_t lastRcvdEchoSeq;

    Reachability *internetReachability;
    NetworkStatus lastInternetStatus;
    
    NSMutableSet *displayedServerAlerts;
    int anotherConnectionCount;
    BOOL serverInInitialQueueSend;
    BOOL isWaitingForReconnect;
}

@synthesize connectionState;
@synthesize lastRtt;

#pragma pack(push, 1)
#pragma pack(1)

struct pktClientHello {
	unsigned char client_tempkey_pub[kNaClCryptoPubKeySize];
	unsigned char client_cookie[kCookieLen];
};

struct pktServerHelloBox {
    unsigned char server_tempkey_pub[kNaClCryptoPubKeySize];
	unsigned char client_cookie[kCookieLen];
};

struct pktServerHello {
    unsigned char server_cookie[kCookieLen];
    char box[sizeof(struct pktServerHelloBox) + kNaClBoxOverhead];
};

struct pktVouch {
	unsigned char client_tempkey_pub[kNaClCryptoPubKeySize];
};

struct pktLogin {
	char identity[kIdentityLen];
    char client_version[kClientVersionLen];
	unsigned char server_cookie[kCookieLen];
	unsigned char vouch_nonce[kNaClCryptoNonceSize];
	char vouch_box[sizeof(struct pktVouch) + kNaClBoxOverhead];
};

struct pktLoginAck {
    char reserved[kLoginAckReservedLen];
};

struct pktPayload {
    uint8_t type;
    uint8_t reserved[3];
    char data[];
};

#pragma pack(pop)

#define TAG_CLIENT_HELLO_SENT 1
#define TAG_SERVER_HELLO_READ 2
#define TAG_LOGIN_SENT 3
#define TAG_LOGIN_ACK_READ 4
#define TAG_PAYLOAD_SENT 5
#define TAG_PAYLOAD_LENGTH_READ 6
#define TAG_PAYLOAD_READ 7

+ (ServerConnector*)sharedServerConnector {
    static ServerConnector *instance;
	
	@synchronized (self) {
		if (!instance)
			instance = [[ServerConnector alloc] init];
	}
	
	return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        /* Read server info */
        if ([LicenseStore requiresLicenseKey]) {
            serverNamePrefix = [BundleUtil objectForInfoDictionaryKey:@"ThreemaWorkServerNamePrefix"];
            serverNamePrefixv6 = [BundleUtil objectForInfoDictionaryKey:@"ThreemaWorkServerNamePrefixv6"];
        } else {
            serverNamePrefix = [BundleUtil objectForInfoDictionaryKey:@"ThreemaServerNamePrefix"];
            serverNamePrefixv6 = [BundleUtil objectForInfoDictionaryKey:@"ThreemaServerNamePrefixv6"];
        }
        serverNameSuffix = [BundleUtil objectForInfoDictionaryKey:@"ThreemaServerNameSuffix"];
        serverPorts = [BundleUtil objectForInfoDictionaryKey:@"ThreemaServerPorts"];
        curServerPortIndex = 0;
        serverKeyPub = [BundleUtil objectForInfoDictionaryKey:@"ThreemaServerPublicKey"];
        serverAltKeyPub = [BundleUtil objectForInfoDictionaryKey:@"ThreemaServerAltPublicKey"];
        
        queue = dispatch_queue_create("ch.threema.SocketQueue", NULL);
        disconnectCondition = [[NSCondition alloc] init];
        
        reconnectAttempts = 0;
        lastSentEchoSeq = 0;
        lastRcvdEchoSeq = 0;
        self.connectionState = ConnectionStateDisconnected;
        
        displayedServerAlerts = [NSMutableSet set];
        
        /* register with reachability API */
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStatusDidChange:) name:kReachabilityChangedNotification object:nil];
		
		internetReachability = [Reachability reachabilityForInternetConnection];
        lastInternetStatus = [internetReachability currentReachabilityStatus];
		[internetReachability startNotifier];
        
        isWaitingForReconnect = false;
        
        /* listen for identity changes */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(identityCreated:) name:kNotificationCreatedIdentity object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(identityDestroyed:) name:kNotificationDestroyedIdentity object:nil];
    }
    return self;
}

- (void)connect {
    dispatch_async(queue, ^{
        lastErrorDisplay = nil;
        [self _connect];
    });
}

- (void)connectWait {
    dispatch_sync(queue, ^{
        lastErrorDisplay = nil;
        [self _connect];
    });
}

- (void)_connect {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
        return;
    }
        
    if (![[MyIdentityStore sharedMyIdentityStore] isProvisioned]) {
        DDLogInfo(@"Cannot connect - missing identity or key");
        [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Cannot connect - missing identity or key"]];
        return;
    }
    
    if (self.connectionState == ConnectionStateDisconnecting) {
        // The socketDidDisconnect callback has not been called yet; ensure that we reconnect
        // as soon as the previous disconnect has finished.
        reconnectAttempts = 1;
        autoReconnect = YES;
        return;
    } else if (self.connectionState != ConnectionStateDisconnected) {
        if (self.connectionState == ConnectionStateLoggedIn) {
            return;
        }
        NSString *error = [NSString stringWithFormat:@"Cannot connect - invalid connection state (actual state: %u)", self.connectionState];
        DDLogInfo(@"%@", error);
        [[ValidationLogger sharedValidationLogger] logString:error];
        autoReconnect = YES;
        [self reconnectAfterDelay];
        return;
    }
    
    if ([AppGroup amIActive] == NO) {
        DDLogInfo(@"Not active -> don't connect now, retry later");
        [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Not active -> don't connect now, retry later"]];
        // keep delay at constant rate to avoid too long waits when becoming active again
        reconnectAttempts = 1;
        autoReconnect = YES;
        [self reconnectAfterDelay];
        return;
    }

    LicenseStore *licenseStore = [LicenseStore sharedLicenseStore];
    if ([licenseStore isValid] == NO) {
        [licenseStore performLicenseCheckWithCompletion:^(BOOL success) {
            if (success) {
                [self connect];
            } else {
                // don't show license warning for connection errors
                [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"License check failed: %@", licenseStore.error]];
                if ([licenseStore.error.domain hasPrefix:@"NSURL"] == NO) {
                    // License check failed permanently; need to inform user and ask for new license username/password
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLicenseMissing object:nil];
                } else {
                    // License check failed due to connection error – try again later
                    autoReconnect = YES;
                    [self reconnectAfterDelay];
                }
            }
        }];
        
        return;
    }
    
    [[LicenseStore sharedLicenseStore] performUpdateWorkInfo];

    self.connectionState = ConnectionStateConnecting;
    autoReconnect = YES;
    self.lastRtt = -1;
    lastRead = CACurrentMediaTime();
    serverInInitialQueueSend = YES;
    
    /* Generate a new key pair for the server connection. */
    time_t uptime = [Utils systemUptime];
    DDLogVerbose(@"System uptime is %ld", uptime);
    if (clientTempKeyPub == nil || clientTempKeySec == nil || uptime <= 0 || (uptime - clientTempKeyGenTime) > kClientTempKeyMaxAge) {
        NSData *publicKey, *secretKey;
        [[NaClCrypto sharedCrypto] generateKeyPairPublicKey:&publicKey secretKey:&secretKey];
        clientTempKeyPub = publicKey;
        clientTempKeySec = secretKey;
        clientTempKeyGenTime = uptime;
#if LOG_KEY_INFO
        DDLogVerbose(@"Client tempkey_pub = %@, tempkey_sec = %@", clientTempKeyPub, clientTempKeySec);
#endif
    }
    
    /* Determine server host name */
    NSString *serverHost;
    NSTimeInterval timeout = kConnectTimeout;
    if ([UserSettings sharedUserSettings].enableIPv6) {
        serverHost = [NSString stringWithFormat:@"%@%@%@", serverNamePrefixv6, [MyIdentityStore sharedMyIdentityStore].serverGroup, serverNameSuffix];
    } else {
        serverHost = [NSString stringWithFormat:@"%@%@%@", serverNamePrefix, [MyIdentityStore sharedMyIdentityStore].serverGroup, serverNameSuffix];
    }
    
    NSNumber* serverPort = [serverPorts objectAtIndex:curServerPortIndex];
    
    socket = [GCDAsyncSocketFactory proxyAwareAsyncSocketForHost:serverHost port:serverPort delegate:self delegateQueue:queue];
    if ([UserSettings sharedUserSettings].enableIPv6) {
        [socket setIPv4PreferredOverIPv6:NO];
    } else {
        [socket setIPv4PreferredOverIPv6:YES];
    }
              
    DDLogInfo(@"Connecting to %@:%@...", serverHost, serverPort);
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Connecting to %@:%@...", serverHost, serverPort]];
    
    NSError *error;
    if (![socket connectToHost:serverHost onPort:[serverPort intValue] withTimeout:timeout error:&error]) {
        DDLogWarn(@"Connect failed: %@", error);
        [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Connect failed: %@", error]];
        self.connectionState = ConnectionStateDisconnected;
        [self reconnectAfterDelay];
        return;
    }
    
    /* Reset nonces for new connection */
    clientNonce = 1;
    serverNonce = 1;
}

- (void)_disconnect {
    if (connectionState == ConnectionStateDisconnected) {
        return;
    }
    
    /* disconnect socket and make sure we don't reconnect */
    autoReconnect = NO;
    self.connectionState = ConnectionStateDisconnecting;
    [self _disconnectSocketWithTimeout];
}

- (void)_disconnectSocketWithTimeout {
    // Give the socket time for pending writes, but force disconnect if it takes too long for them to complete
    [socket disconnectAfterWriting];
    
    GCDAsyncSocket *socketToDisconnect = socket;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDisconnectTimeout * NSEC_PER_SEC)), queue, ^{
        if (socket == socketToDisconnect) {
            DDLogInfo(@"Socket still not disconnected - forcing disconnect now");
            [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Socket still not disconnected - forcing disconnect now"]];
            [socket disconnect];
        }
    });
}

- (void)disconnect {
    dispatch_async(queue, ^{
        [self _disconnect];
    });
}

- (void)disconnectWait {
    dispatch_sync(queue, ^{
        [self _disconnect];
    });
    
    [disconnectCondition lock];
    if (connectionState != ConnectionStateDisconnected) {
        [disconnectCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:kDisconnectTimeout]];
    }
    // Note: it's not guaranteed that the state is actually disconnected at this point, but it's good enough for our purposes
    [disconnectCondition unlock];
}

- (void)reconnect {
    dispatch_async(queue, ^{
        if (connectionState == ConnectionStateDisconnected) {
            [self _connect];
        } else if (connectionState == ConnectionStateConnecting) {
            DDLogVerbose(@"Connection already in progress, not reconnecting");
        } else {
            autoReconnect = YES;
            self.connectionState = ConnectionStateDisconnecting;
            [self _disconnectSocketWithTimeout];
        }
    });
}

- (void)setConnectionState:(enum ConnectionState)newConnectionState {
    [disconnectCondition lock];
    connectionState = newConnectionState;
    if (connectionState == ConnectionStateDisconnected) {
        [disconnectCondition broadcast];
    }
    [disconnectCondition unlock];
}

- (void)processPayload:(struct pktPayload*)pl datalen:(int)datalen {
    
    switch (pl->type) {
        case PLTYPE_ECHO_REPLY: {
            self.lastRtt = CACurrentMediaTime() - lastEchoSendTime;
            if (datalen == sizeof(lastRcvdEchoSeq)) {
                memcpy(&lastRcvdEchoSeq, pl->data, sizeof(lastRcvdEchoSeq));
            } else {
                DDLogError(@"Bad echo reply datalen %d", datalen);
                [socket disconnect];
                break;
            }
            DDLogInfo(@"Received echo reply (seq %llu, RTT %.1f ms)", lastRcvdEchoSeq, self.lastRtt * 1000);
            break;
        }
        case PLTYPE_ERROR: {
            if (datalen < sizeof(struct plError)) {
                DDLogError(@"Bad error payload datalen %d", datalen);
                [socket disconnect];
                break;
            }
            struct plError *plerr = (struct plError*)pl->data;
            NSData *errorMessageData = [NSData dataWithBytes:plerr->err_message length:datalen - sizeof(struct plError)];
            NSString *errorMessage = [[NSString alloc] initWithData:errorMessageData encoding:NSUTF8StringEncoding];
            DDLogError(@"Received error message from server: %@", errorMessage);
            
            if ([errorMessage rangeOfString:@"Another connection"].location != NSNotFound) {
                // extension took over connection
                if ([AppGroup amIActive] == NO) {
                    break;
                }
                
                // ignore first few occurrences of "Another connection" messages to gracefully handle network switches
                if (anotherConnectionCount < 5) {
                    anotherConnectionCount++;
                    break;
                }
            }
            
            if (!plerr->reconnect_allowed) {
                autoReconnect = NO;
            }
            
            if (lastErrorDisplay == nil || ((-[lastErrorDisplay timeIntervalSinceNow]) > kErrorDisplayInterval)) {
                lastErrorDisplay = [NSDate date];
                
                
                NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                      errorMessage, kKeyMessage,
                                      nil];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationErrorConnectionFailed object:nil userInfo:info];
            }
            break;
        }
        case PLTYPE_ALERT: {
            NSData *alertData = [NSData dataWithBytes:pl->data length:datalen];
            NSString *alertText = [[NSString alloc] initWithData:alertData encoding:NSUTF8StringEncoding];
            [self displayServerAlert:alertText];
            break;
        }
        case PLTYPE_OUTGOING_MESSAGE_ACK: {
            if (datalen != sizeof(struct plMessageAck)) {
                DDLogError(@"Bad ACK payload datalen %d", datalen);
                [socket disconnect];
                break;
            }
            
            struct plOutgoingMessageAck *ack = (struct plOutgoingMessageAck*)pl->data;
            /* ignore from identity, as it must be ours */
            NSData *messageId = [NSData dataWithBytes:ack->message_id length:kMessageIdLen];
            NSString *toIdentity = [[NSString alloc] initWithData:[NSData dataWithBytes:ack->to_identity length:kIdentityLen] encoding:NSASCIIStringEncoding];
            [[MessageQueue sharedMessageQueue] processAck:messageId toIdentity:toIdentity];
            break;
        }
        case PLTYPE_INCOMING_MESSAGE: {
            if (datalen <= sizeof(struct plMessage)) {
                DDLogError(@"Bad message payload datalen %d", datalen);
                [socket disconnect];
                break;
            }
            struct plMessage *plmsg = (struct plMessage*)pl->data;
            
            BoxedMessage *boxmsg = [[BoxedMessage alloc] init];
            boxmsg.fromIdentity = [[NSString alloc] initWithData:[NSData dataWithBytes:plmsg->from_identity length:kIdentityLen] encoding:NSASCIIStringEncoding];
            boxmsg.toIdentity = [[NSString alloc] initWithData:[NSData dataWithBytes:plmsg->to_identity length:kIdentityLen] encoding:NSASCIIStringEncoding];
            boxmsg.messageId = [NSData dataWithBytes:plmsg->message_id length:kMessageIdLen];
            boxmsg.date = [NSDate dateWithTimeIntervalSince1970:plmsg->date];
            boxmsg.flags = plmsg->flags;
            char pushFromNameT[kPushFromNameLen+1];
            memcpy(pushFromNameT, plmsg->push_from_name, kPushFromNameLen);
            pushFromNameT[kPushFromNameLen] = 0;
            boxmsg.pushFromName = [NSString stringWithCString:pushFromNameT encoding:NSUTF8StringEncoding];
            boxmsg.nonce = [NSData dataWithBytes:plmsg->nonce length:kNonceLen];
            boxmsg.box = [NSData dataWithBytes:plmsg->box length:(datalen - sizeof(struct plMessage))];
            
            [MessageProcessorProxy processIncomingMessage:boxmsg receivedAfterInitialQueueSend:!serverInInitialQueueSend onCompletion:^{
                [self completedProcessingMessage:boxmsg];
            } onError:^(NSError *err) {
                [self failedProcessingMessage:boxmsg error:err];
            }];
            
            break;
        }
        case PLTYPE_QUEUE_SEND_COMPLETE:
            DDLogInfo(@"Queue send complete");
            serverInInitialQueueSend = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationQueueSendComplete object:nil userInfo:nil];
            break;
        default:
            DDLogWarn(@"Unsupported payload type %d", pl->type);
            break;
    }
}

- (void)completedProcessingMessage:(BoxedMessage *)boxmsg {
    if (!(boxmsg.flags & MESSAGE_FLAG_NOACK)) {
        /* send ACK to server */
        [self ackMessage:boxmsg.messageId fromIdentity:boxmsg.fromIdentity];
    }
}

- (void)completedProcessingAbstractMessage:(AbstractGroupMessage *)abstractGroupMsg {
    uint8_t flags = abstractGroupMsg.flags.unsignedCharValue;
    if (!(flags & MESSAGE_FLAG_NOACK)) {
        /* send ACK to server */
        [self ackMessage:abstractGroupMsg.messageId fromIdentity:abstractGroupMsg.fromIdentity];
    }
}


- (void)failedProcessingMessage:(BoxedMessage *)boxmsg error:(NSError *)err {
    if (err.code == kBlockUnknownContactErrorCode) {
        DDLogVerbose(@"Message processing error due to block contacts - acking anyway");
        [self ackMessage:boxmsg.messageId fromIdentity:boxmsg.fromIdentity];
    } else if (err.code == kBadMessageErrorCode) {
        DDLogVerbose(@"Message processing error due to bad message format or decryption failure - acking anyway");
        [self ackMessage:boxmsg.messageId fromIdentity:boxmsg.fromIdentity];
    } else if (err.code == kMessageProcessingErrorCode) {
        DDLogError(@"Message processing error due to being unable to handle message: %@", err);
   } else {
        DDLogInfo(@"Could not process incoming message: %@", err);
    }
}

- (void)reconnectAfterDelay {
    if (!autoReconnect) {
        return;
    }
    
    /* calculate delay using bound exponential backoff */
    float reconnectDelay = powf(kReconnectBaseInterval, MIN(reconnectAttempts - 1, 10));
    if (reconnectDelay > kReconnectMaxInterval) {
        reconnectDelay = kReconnectMaxInterval;
    }
    
    if (!isWaitingForReconnect) {
        isWaitingForReconnect = true;
        [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Waiting %f seconds before reconnecting", reconnectDelay]];
        
        reconnectAttempts++;
        DDLogInfo(@"Waiting %f seconds before reconnecting", reconnectDelay);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, reconnectDelay * NSEC_PER_SEC);
        dispatch_after(popTime, queue, ^(void){
            isWaitingForReconnect = false;
            [self _connect];
        });
    }
}

- (void)sendPayloadWithType:(uint8_t)type data:(NSData*)data {
    if (connectionState != ConnectionStateLoggedIn) {
        DDLogVerbose(@"Cannot send payload - not logged in");
        return;
    }
    
    dispatch_async(queue, ^{
        [self sendPayloadAsyncWithType:type data:data];
    });
}

- (void)sendPayloadAsyncWithType:(uint8_t)type data:(NSData*)data {
    /* Make encrypted box */
    unsigned long pllen = sizeof(struct pktPayload) + data.length;
    struct pktPayload *pl = malloc(pllen);
    if (!pl) {
        return;
    }
    
    bzero(pl, pllen);
    
    pl->type = type;
    memcpy(pl->data, data.bytes, data.length);
    
    NSData *plData = [NSData dataWithBytesNoCopy:pl length:pllen];
    NSData *nextClientNonce = [self nextClientNonce];
    NSData *plBox = [[NaClCrypto sharedCrypto] encryptData:plData withPublicKey:serverTempKeyPub signKey:clientTempKeySec nonce:nextClientNonce];
    if (plBox == nil) {
        DDLogError(@"Payload encryption failed!");
        return;
    }
    
    /* prepend length - make one NSData object to pass to socket to ensure it is sent
       in a single TCP segment */
    uint16_t pktlen = plBox.length;
    
    if (pktlen > kMaxPktLen) {
        DDLogError(@"Packet is too big (%d) - cannot send", pktlen);
        return;
    }
    
    NSMutableData *sendData = [NSMutableData dataWithCapacity:plBox.length + sizeof(uint16_t)];
    [sendData appendBytes:&pktlen length:sizeof(uint16_t)];
    [sendData appendData:plBox];
    
    [socket writeData:sendData withTimeout:kWriteTimeout tag:TAG_PAYLOAD_SENT];
    return;
}

- (void)sendMessage:(BoxedMessage*)message {
    unsigned long msglen = sizeof(struct plMessage) + message.box.length;
    struct plMessage *plmsg = malloc(msglen);
    if (!plmsg) {
        return;
    }
    
    DDLogInfo(@"Sending message from %@ to %@ (ID %@), box length %lu", message.fromIdentity,
          message.toIdentity, message.messageId, (unsigned long)message.box.length);
    
    memcpy(plmsg->from_identity, [message.fromIdentity dataUsingEncoding:NSASCIIStringEncoding].bytes, kIdentityLen);
    memcpy(plmsg->to_identity, [message.toIdentity dataUsingEncoding:NSASCIIStringEncoding].bytes, kIdentityLen);
    memcpy(plmsg->message_id, message.messageId.bytes, kMessageIdLen);
    plmsg->date = [message.date timeIntervalSince1970];
    plmsg->flags = message.flags;
    plmsg->reserved[0] = 0; plmsg->reserved[1] = 0; plmsg->reserved[2] = 0;
    bzero(plmsg->push_from_name, kPushFromNameLen);
    if (message.pushFromName != nil) {
        NSData *encodedPushFromName = [Utils truncatedUTF8String:message.pushFromName maxLength:kPushFromNameLen];
        strncpy(plmsg->push_from_name, encodedPushFromName.bytes, encodedPushFromName.length);
    }
    memcpy(plmsg->nonce, message.nonce.bytes, kNaClCryptoNonceSize);
    memcpy(plmsg->box, message.box.bytes, message.box.length);
    
    [self sendPayloadWithType:PLTYPE_OUTGOING_MESSAGE data:[NSData dataWithBytesNoCopy:plmsg length:msglen]];
}

- (void)ackMessage:(NSData*)messageId fromIdentity:(NSString*)fromIdentity {
    int msglen = sizeof(struct plMessageAck);
    struct plMessageAck *plmsgack = malloc(msglen);
    if (!plmsgack)
        return;
    
    DDLogInfo(@"Sending ack for message ID %@ from %@", messageId, fromIdentity);
    
    memcpy(plmsgack->from_identity, [fromIdentity dataUsingEncoding:NSASCIIStringEncoding].bytes, kIdentityLen);
    memcpy(plmsgack->message_id, messageId.bytes, kMessageIdLen);
    
    [self sendPayloadWithType:PLTYPE_INCOMING_MESSAGE_ACK data:[NSData dataWithBytesNoCopy:plmsgack length:msglen]];
}

- (void)ping {
    dispatch_async(queue, ^{
        [self sendEchoRequest];
    });
}

- (void)sendEchoRequest {
    if (connectionState != ConnectionStateLoggedIn)
        return;
    
    lastSentEchoSeq++;
    DDLogInfo(@"Sending echo request (seq %llu)", lastSentEchoSeq);
    
    lastEchoSendTime = CACurrentMediaTime();
    [self sendPayloadAsyncWithType:PLTYPE_ECHO_REQUEST data:[NSData dataWithBytes:&lastSentEchoSeq length:sizeof(lastSentEchoSeq)]];
    
    GCDAsyncSocket *curSocket = socket;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kReadTimeout * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        if (curSocket == socket && lastRcvdEchoSeq < lastSentEchoSeq) {
            DDLogInfo(@"No reply to echo payload; disconnecting");
            [socket disconnect];
        }
    });
}

- (void)cleanPushToken {
    if ([[AppGroup userDefaults] objectForKey:kPushNotificationDeviceToken] != nil) {
        [[AppGroup userDefaults] setObject:nil forKey:kPushNotificationDeviceToken];
        [[AppGroup userDefaults] synchronize];
    }

    [self sendPushToken];
    [self sendPushAllowedIdentities];
    [self sendPushSound];
}

- (void)setVoIPPushToken:(NSData *)voIPPushToken {
    [[AppGroup userDefaults] setObject:voIPPushToken forKey:kVoIPPushNotificationDeviceToken];
    [[AppGroup userDefaults] synchronize];
    [self sendVoIPPushToken];
}

- (void)sendPushToken {
    if ([self shouldRegisterPush] == NO) {
        return;
    }
        
    DDLogInfo(@"Sending push notification token");
    
    uint8_t pushTokenType = PUSHTOKEN_TYPE_NONE;
    NSMutableData *payloadData = [NSMutableData dataWithBytes:&pushTokenType length:1];
    
    [self sendPayloadWithType:PLTYPE_PUSH_NOTIFICATION_TOKEN data:payloadData];
}

- (void)sendVoIPPushToken {
    if ([self shouldRegisterVoIP] == NO) {
        return;
    }
    
    NSData *voIPPushToken = [[AppGroup userDefaults] objectForKey:kVoIPPushNotificationDeviceToken];
    
    DDLogInfo(@"Sending VoIP push notification token");
    
    uint8_t voIPPushTokenType;
#ifdef DEBUG
        voIPPushTokenType = PUSHTOKEN_TYPE_APPLE_SANDBOX;
#else
        voIPPushTokenType = PUSHTOKEN_TYPE_APPLE_PROD;
#endif
    
    NSMutableData *payloadData = [NSMutableData dataWithBytes:&voIPPushTokenType length:1];
    [payloadData appendData:voIPPushToken];
    [payloadData appendData:[@"|" dataUsingEncoding:NSUTF8StringEncoding]];
    [payloadData appendData:[[[NSBundle mainBundle] bundleIdentifier] dataUsingEncoding:NSASCIIStringEncoding]];
    [payloadData appendData:[@"|" dataUsingEncoding:NSUTF8StringEncoding]];
    [payloadData appendData:[PushPayloadDecryptor pushEncryptionKey]];
    [self sendPayloadWithType:PLTYPE_VOIP_PUSH_NOTIFICATION_TOKEN data:payloadData];
}

- (void)sendPushAllowedIdentities {
    if ([self shouldRegisterPush] == NO) {
        return;
    }
    
    // Disable filter by allowing all IDs; we filter pushes in our own logic now
    DDLogInfo(@"Sending push allowed identities");
    dispatch_async(dispatch_get_main_queue(), ^{
        NSData *iddata = [NSData dataWithBytes:"\0" length:1];
        
        DDLogVerbose(@"Sending allowed identities: %@", iddata);
        [self sendPayloadWithType:PLTYPE_PUSH_ALLOWED_IDENTITIES data:iddata];
    });
}

- (BOOL)shouldRegisterPush {
    if (connectionState != ConnectionStateLoggedIn) {
        return NO;
    }
    
    if ([AppGroup getCurrentType] != AppGroupTypeApp) {
        // only register within main app for pushes
        return NO;
    }
    
    return YES;
}

- (BOOL)shouldRegisterVoIP {
    if (connectionState != ConnectionStateLoggedIn) {
        return NO;
    }
    
    if ([[AppGroup userDefaults] objectForKey:kVoIPPushNotificationDeviceToken] == nil) {
        return NO;
    }
    
    if ([AppGroup getCurrentType] != AppGroupTypeApp) {
        // only register within main app for pushes
        return NO;
    }
    
    return YES;
}

- (void)sendPushSound{
    if ([self shouldRegisterPush] == NO) {
        return;
    }
    
    NSString *pushSound = @"";
    DDLogInfo(@"Sending push sound: %@", pushSound);
    [self sendPayloadWithType:PLTYPE_PUSH_SOUND data:[pushSound dataUsingEncoding:NSASCIIStringEncoding]];
}

- (void)sendPushGroupSound {
    if ([self shouldRegisterPush] == NO) {
        return;
    }
    
    NSString *pushGroupSound = @"";
    
    DDLogInfo(@"Sending push group sound: %@", pushGroupSound);
    [self sendPayloadWithType:PLTYPE_PUSH_GROUP_SOUND data:[pushGroupSound dataUsingEncoding:NSASCIIStringEncoding]];
}

- (NSData*)nextClientNonce {
    char nonce[kNaClCryptoNonceSize];
    memcpy(nonce, clientCookie.bytes, kCookieLen);
    memcpy(&nonce[kCookieLen], &clientNonce, sizeof(clientNonce));
    clientNonce++;
    return [NSData dataWithBytes:nonce length:kNaClCryptoNonceSize];
}

- (NSData*)nextServerNonce {
    char nonce[kNaClCryptoNonceSize];
    memcpy(nonce, serverCookie.bytes, kCookieLen);
    memcpy(&nonce[kCookieLen], &serverNonce, sizeof(serverNonce));
    serverNonce++;
    return [NSData dataWithBytes:nonce length:kNaClCryptoNonceSize];
}

- (NSString*)nameForConnectionState:(enum ConnectionState)_connectionState {
    switch (_connectionState) {
        case ConnectionStateDisconnected:
            return @"disconnected";
        case ConnectionStateConnecting:
            return @"connecting";
        case ConnectionStateConnected:
            return @"connected";
        case ConnectionStateLoggedIn:
            return @"loggedin";
        case ConnectionStateDisconnecting:
            return @"disconnecting";
    }
    return nil;
}

- (BOOL)isIPv6Connection {
    return [socket isIPv6];
}

- (BOOL)isProxyConnection {
    return (socket != nil && ![socket isMemberOfClass:[GCDAsyncSocket class]]);
}

- (void)displayServerAlert:(NSString*)alertText {
    
    if ([displayedServerAlerts containsObject:alertText])
        return;
    
    /* not shown before */
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          alertText, kKeyMessage,
                          nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationServerMessage object:nil userInfo:info];
    
    [displayedServerAlerts addObject:alertText];
}

- (void)networkStatusDidChange:(NSNotification *)notice
{
	NetworkStatus internetStatus = [internetReachability currentReachabilityStatus];
	switch (internetStatus) {
		case NotReachable:
			DDLogInfo(@"Internet is not reachable");
            [[ValidationLogger sharedValidationLogger] logString:@"Internet is not reachable"];
			break;
		case ReachableViaWiFi:
			DDLogInfo(@"Internet is reachable via WiFi");
            [[ValidationLogger sharedValidationLogger] logString:@"Internet is reachable via WiFi"];
			break;
		case ReachableViaWWAN:
			DDLogInfo(@"Internet is reachable via WWAN");
            [[ValidationLogger sharedValidationLogger] logString:@"Internet is reachable via WWAN"];
			break;
	}
    
    if (internetStatus != lastInternetStatus) {
        DDLogInfo(@"Internet status changed - forcing reconnect");
        [[ValidationLogger sharedValidationLogger] logString:@"Internet status changed - forcing reconnect"];
        curServerPortIndex = 0;
        [self reconnect];
        lastInternetStatus = internetStatus;
    }
}

- (void)setServerPorts:(NSArray *)ports {
    serverPorts = ports;
}

- (void)sendPushOverrideTimeout {
    DDLogInfo(@"Sending set push override timeout");
    NSUserDefaults *defaults = [AppGroup userDefaults];
    NSDate *lastSendDate = [defaults objectForKey:kLastPushOverrideSendDate];
    
    if (lastSendDate == nil) {
        [self setPushOverrideTimeout];
    } else {
        NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitMinute fromDate:lastSendDate toDate:[NSDate date] options:0];
        NSInteger minutes = [components minute];
        
        if (minutes > 60 || lastSendDate == nil) {
            [self setPushOverrideTimeout];
        }
    }
}

- (void)setPushOverrideTimeout {
    NSUserDefaults *defaults = [AppGroup userDefaults];
    NSTimeInterval secondsInEightHours = 8 * 60 * 60;
    NSDate *pushOverrideEndDate = [[NSDate date] dateByAddingTimeInterval:secondsInEightHours];
    uint64_t timestamp = [pushOverrideEndDate timeIntervalSince1970];
    NSData *payloadData = [NSData dataWithBytes:&timestamp length:sizeof(timestamp)];
    [self sendPayloadWithType:PLTYPE_PUSH_OVERRIDE_TIMEOUT data:payloadData];
    
    [defaults setObject:[NSDate date] forKey:kLastPushOverrideSendDate];
    [defaults synchronize];
}

- (void)resetPushOverrideTimeout {
    DDLogInfo(@"Reset push override timeout");
    NSUserDefaults *defaults = [AppGroup userDefaults];
    
    uint64_t timestamp = 0;
    NSData *data = [NSData dataWithBytes:&timestamp length:sizeof(timestamp)];
    [self sendPayloadWithType:PLTYPE_PUSH_OVERRIDE_TIMEOUT data:data];
    [defaults setObject:nil forKey:kLastPushOverrideSendDate];
    [defaults synchronize];
}


#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sender didConnectToHost:(NSString *)host port:(UInt16)port {
    if (sender != socket) {
        DDLogWarn(@"didConnectToHost from old socket");
        return;
    }
    
    DDLogInfo(@"Connected to %@:%d", host, port);
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Connected to %@:%d", host, port]];
    self.connectionState = ConnectionStateConnected;
    
    /* Send client hello packet with temporary public key and client cookie */
    clientCookie = [[NaClCrypto sharedCrypto] randomBytes:kCookieLen];
    DDLogVerbose(@"Client cookie = %@", clientCookie);
    
    /* Make sure to pass everything in one writeData call, or we will get two separate TCP segments */
    struct pktClientHello clientHello;
    memcpy(clientHello.client_tempkey_pub, clientTempKeyPub.bytes, sizeof(clientHello.client_tempkey_pub));
    memcpy(clientHello.client_cookie, clientCookie.bytes, sizeof(clientHello.client_cookie));
    [socket writeData:[NSData dataWithBytes:&clientHello length:sizeof(clientHello)] withTimeout:kWriteTimeout tag:TAG_CLIENT_HELLO_SENT];
    
    /* Prepare to receive server hello packet */
    [socket readDataToLength:sizeof(struct pktServerHello) withTimeout:kReadTimeout tag:TAG_SERVER_HELLO_READ];
}

- (void)socket:(GCDAsyncSocket *)sender didReadData:(NSData *)data withTag:(long)tag {
    //DDLogVerbose(@"Read data (%d bytes) with tag: %ld", data.length, tag);
    
    if (sender != socket) {
        DDLogWarn(@"didReadData from old socket");
        return;
    }
    
    switch (tag) {
        case TAG_SERVER_HELLO_READ: {
            DDLogVerbose(@"Got server hello!");
            const struct pktServerHello* serverHello = data.bytes;
            
            serverCookie = [NSData dataWithBytes:serverHello->server_cookie length:sizeof(serverHello->server_cookie)];
            DDLogVerbose(@"Server cookie = %@", serverCookie);
            
            /* decrypt server hello box */
            chosenServerKeyPub = serverKeyPub;
            NSData *serverHelloBox = [NSData dataWithBytes:serverHello->box length:sizeof(serverHello->box)];
            NSData *nonce = [self nextServerNonce];
            NSData *serverHelloBoxOpen = [[NaClCrypto sharedCrypto] decryptData:serverHelloBox withSecretKey:clientTempKeySec signKey:chosenServerKeyPub nonce:nonce];
            if (serverHelloBoxOpen == nil) {
                /* try alternate key */
                chosenServerKeyPub = serverAltKeyPub;
                serverHelloBoxOpen = [[NaClCrypto sharedCrypto] decryptData:serverHelloBox withSecretKey:clientTempKeySec signKey:chosenServerKeyPub nonce:nonce];
                if (serverHelloBoxOpen == nil) {
                    DDLogError(@"Decryption of server hello box failed");
                    [socket disconnect];
                    return;
                } else {
                    DDLogWarn(@"Using alternate server key!");
                }
            }
            
            const struct pktServerHelloBox *serverHelloBoxU = (struct pktServerHelloBox*)serverHelloBoxOpen.bytes;
            
            /* verify client cookie */
            NSData *clientCookieFromServer = [NSData dataWithBytes:serverHelloBoxU->client_cookie length:sizeof(serverHelloBoxU->client_cookie)];
            if (![clientCookieFromServer isEqualToData:clientCookie]) {
                DDLogError(@"Client cookie mismatch (mine: %@, server: %@)", clientCookie, clientCookieFromServer);
                [socket disconnect];
                return;
            }
            
            /* copy temporary server key */
            serverTempKeyPub = [NSData dataWithBytes:serverHelloBoxU->server_tempkey_pub length:sizeof(serverHelloBoxU->server_tempkey_pub)];
            
            DDLogInfo(@"Server hello successful, tempkey_pub = %@", serverTempKeyPub);
            
            /* now prepare login packet */
            NSData *vouchNonce = [[NaClCrypto sharedCrypto] randomBytes:kNaClCryptoNonceSize];
            struct pktLogin login;
            memcpy(login.identity, [[MyIdentityStore sharedMyIdentityStore].identity dataUsingEncoding:NSASCIIStringEncoding].bytes, kIdentityLen);
            bzero(login.client_version, kClientVersionLen);
            NSData *clientVersion = [[Utils getClientVersion] dataUsingEncoding:NSASCIIStringEncoding];
            memcpy(login.client_version, clientVersion.bytes, MIN(clientVersion.length, kClientVersionLen));
            memcpy(login.server_cookie, serverCookie.bytes, kCookieLen);
            memcpy(login.vouch_nonce, vouchNonce.bytes, kNaClCryptoNonceSize);
            
            /* vouch subpacket */
            struct pktVouch vouch;
            memcpy(vouch.client_tempkey_pub, clientTempKeyPub.bytes, kNaClCryptoPubKeySize);
            NSData *vouchBox = [[MyIdentityStore sharedMyIdentityStore] encryptData:[NSData dataWithBytes:&vouch length:sizeof(vouch)] withNonce:vouchNonce publicKey:chosenServerKeyPub];
            memcpy(login.vouch_box, vouchBox.bytes, sizeof(login.vouch_box));
            
            /* encrypt login packet */
            NSData *loginBox = [[NaClCrypto sharedCrypto] encryptData:[NSData dataWithBytes:&login length:sizeof(login)] withPublicKey:serverTempKeyPub signKey:clientTempKeySec nonce:[self nextClientNonce]];
            
            /* send it! */
            [socket writeData:loginBox withTimeout:kWriteTimeout tag:TAG_LOGIN_SENT];
            
            /* Prepare to receive login ack packet */
            [socket readDataToLength:sizeof(struct pktLoginAck) + kNaClBoxOverhead withTimeout:kReadTimeout tag:TAG_LOGIN_ACK_READ];
            
            break;
        }
            
        case TAG_LOGIN_ACK_READ: {
            DDLogInfo(@"Login ack received");
            lastRead = CACurrentMediaTime();
            
            /* decrypt server hello box */
            NSData *loginAckBox = data;
            loginAckBox = [[NaClCrypto sharedCrypto] decryptData:loginAckBox withSecretKey:clientTempKeySec signKey:serverTempKeyPub nonce:[self nextServerNonce]];
            if (loginAckBox == nil) {
                DDLogError(@"Decryption of login ack failed");
                [socket disconnect];
                return;
            }
            
            /* Don't care about the contents of the login ACK for now; it only needs to decrypt correctly */
            
            reconnectAttempts = 0;
            self.connectionState = ConnectionStateLoggedIn;
            
            /* Clean and send nil push token info */
            [self cleanPushToken];
            
            /* Send voIP push token info */
            [self sendVoIPPushToken];
            
            /* Schedule task for keepalive */
            keepalive_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
            dispatch_source_set_event_handler(keepalive_timer, ^{
                [self sendEchoRequest];
            });
            dispatch_source_set_timer(keepalive_timer, dispatch_time(DISPATCH_TIME_NOW, kKeepAliveInterval * NSEC_PER_SEC),
                                      kKeepAliveInterval * NSEC_PER_SEC, NSEC_PER_SEC);
            dispatch_resume(keepalive_timer);
            
            /* Receive next payload header */
            [socket readDataToLength:sizeof(uint16_t) withTimeout:-1 tag:TAG_PAYLOAD_LENGTH_READ];
            
            break;
        }
            
        case TAG_PAYLOAD_LENGTH_READ: {
            uint16_t msglen = *((uint16_t*)data.bytes);
            [socket readDataToLength:msglen withTimeout:-1 tag:TAG_PAYLOAD_READ];
            break;
        }
            
        case TAG_PAYLOAD_READ: {
            DDLogVerbose(@"Payload (%lu bytes) received", (unsigned long)data.length);
            
            lastRead = CACurrentMediaTime();
            
            dispatch_source_set_timer(keepalive_timer, dispatch_time(DISPATCH_TIME_NOW, kKeepAliveInterval * NSEC_PER_SEC),
                                      kKeepAliveInterval * NSEC_PER_SEC, NSEC_PER_SEC);
            
            /* Decrypt payload */
            NSData *plData = [[NaClCrypto sharedCrypto] decryptData:data withSecretKey:clientTempKeySec signKey:serverTempKeyPub nonce:[self nextServerNonce]];
            if (plData == nil) {
                DDLogError(@"Payload decryption failed");
                [socket disconnect];
                return;
            }
            
            struct pktPayload *pl = (struct pktPayload*)plData.bytes;
            int datalen = (int)plData.length - (int)sizeof(struct pktPayload);
            DDLogInfo(@"Decrypted payload (type %02x, data %@)", pl->type, [NSData dataWithBytes:pl->data length:datalen]);
            
            [self processPayload:pl datalen:datalen];
            
            /* Receive next payload header */
            [socket readDataToLength:sizeof(uint16_t) withTimeout:-1 tag:TAG_PAYLOAD_LENGTH_READ];
            
            break;
        }
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sender withError:(NSError *)error {
    [[ValidationLogger sharedValidationLogger] logString:@"socketDidDisconnect called"];
    if (sender != socket) {
        DDLogWarn(@"socketDidDisconnect from old socket");
        [[ValidationLogger sharedValidationLogger] logString:@"socketDidDisconnect from old socket"];
        return;
    }
    
    if (error != nil) {
        DDLogWarn(@"Socket disconnected, error = %@", error);
        [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Socket disconnected, error = %@", error]];
        
        /* try next port */
        curServerPortIndex++;
        if (curServerPortIndex >= serverPorts.count)
            curServerPortIndex = 0;
    }
    
    self.connectionState = ConnectionStateDisconnected;
    if (keepalive_timer != nil) {
        dispatch_source_cancel(keepalive_timer);
        keepalive_timer = nil;
    }
    socket = nil;
    [self reconnectAfterDelay];
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sender shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    if (sender != socket) {
        DDLogWarn(@"shouldTimeoutReadWithTag from old socket");
        return 0;
    }
    
    DDLogInfo(@"Read timeout, tag = %ld", tag);
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Read timeout"]];
    [socket disconnect];
    return 0;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sender shouldTimeoutWriteWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    if (sender != socket) {
        DDLogWarn(@"shouldTimeoutWriteWithTag from old socket");
        return 0;
    }
    
    DDLogInfo(@"Write timeout, tag = %ld", tag);
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Write timeout"]];
    [socket disconnect];
    return 0;
}

#pragma mark - Notifications

- (void)identityCreated:(NSNotification*)notification {
    /* when the identity is created, we should connect */
    [self connect];
}

- (void)identityDestroyed:(NSNotification*)notification {
    /* when the identity is destroyed, we must disconnect */
    if (connectionState != ConnectionStateDisconnected) {
        DDLogInfo(@"Disconnecting because identity destroyed");
        
        /* Clear push token on server now to reduce occurrence of push messages being
           delivered to devices that don't use that particular identity anymore */
        DDLogInfo(@"Clearing push notification token");
        uint8_t pushTokenType;
#ifdef DEBUG
        pushTokenType = PUSHTOKEN_TYPE_APPLE_SANDBOX_MC;
#else
        pushTokenType = PUSHTOKEN_TYPE_APPLE_PROD_MC;
#endif
        
        NSMutableData *payloadData = [NSMutableData dataWithBytes:&pushTokenType length:1];
        NSData *pushToken = [[NaClCrypto sharedCrypto] zeroBytes:32];
        [payloadData appendData:pushToken];
        [self sendPayloadWithType:PLTYPE_PUSH_NOTIFICATION_TOKEN data:payloadData];
        
        DDLogInfo(@"Sending VoIP push notification token");
        
        uint8_t voIPPushTokenType;
#ifdef DEBUG
        voIPPushTokenType = PUSHTOKEN_TYPE_APPLE_SANDBOX;
#else
        voIPPushTokenType = PUSHTOKEN_TYPE_APPLE_PROD;
#endif
        
        NSMutableData *voipPayloadData = [NSMutableData dataWithBytes:&voIPPushTokenType length:1];
        NSData *voipPushToken = [[NaClCrypto sharedCrypto] zeroBytes:32];
        [voipPayloadData appendData:voipPushToken];
        [self sendPayloadWithType:PLTYPE_VOIP_PUSH_NOTIFICATION_TOKEN data:voipPayloadData];
        
        [self disconnect];
    }
    
    /* destroy temporary keys, as we cannot reuse them for the new identity */
    dispatch_async(queue, ^{
        clientTempKeyPub = nil;
        clientTempKeySec = nil;
    });
                   
    /* also flush the queue so that messages stuck in it don't later cause problems
       because they have the wrong from identity */
    [[MessageQueue sharedMessageQueue] flush];
}

@end
