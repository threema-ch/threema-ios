//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#import "ThreemaFramework/ThreemaFramework-Swift.h"

#import "ServerConnector.h"
#import "NaClCrypto.h"
#import <ThreemaFramework/ChatTcpSocket.h>
#import <ThreemaFramework/NSData+ConvertUInt64.h>
#import "NSString+Hex.h"
#import "BoxedMessage.h"
#import "MyIdentityStore.h"
#import "ProtocolDefines.h"
#import "ThreemaUtilityObjC.h"
#import "ContactStore.h"
#import "UserSettings.h"
#import "BundleUtil.h"
#import "AppGroup.h"
#import "LicenseStore.h"
#import "PushPayloadDecryptor.h"
#import "DataQueue.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif
#define LOG_KEY_INFO 0

static const int MAX_BYTES_TO_DECRYPT_NO_LIMIT = 0;
static const int MAX_BYTES_TO_DECRYPT_NOTIFICATION_EXTENSION = 500000;

@implementation ServerConnector {
    NSData *clientTempKeyPub;
    NSData *clientTempKeySec;
    NSData *clientCookie;
    
    NSData *serverCookie;
    NSData *serverTempKeyPub;
    
    NSData *chosenServerKeyPub;
    NSData *serverKeyPub;
    NSData *serverAltKeyPub;
    NSData *tempKeyHash;
    
    dispatch_queue_t sendPushTokenQueue;
    dispatch_queue_t removeVoIPPushTokenQueue;
    BOOL isRemovedVoIPPushToken;
    
    uint64_t serverNonce;
    uint64_t clientNonce;
    dispatch_queue_t socketQueue;
    dispatch_queue_t sendMessageQueue;
    dispatch_source_t keepalive_timer;
    NSCondition *disconnectCondition;
    id<SocketProtocol> socket;
    int reconnectAttempts;

    NSMutableArray *connectionInitiators;

    ServerConnectorConnectionState *serverConnectorConnectionState;

    BOOL autoReconnect;
    CFTimeInterval lastRead;
    NSDate *lastErrorDisplay;

    CFTimeInterval lastEchoSendTime;
    uint64_t lastSentEchoSeq;
    uint64_t lastRcvdEchoSeq;

    ReachabilityWrapper *reachabilityWrapper;
    
    NSMutableSet *displayedServerAlerts;
    int anotherConnectionCount;
    BOOL chatServerInInitialQueueSend;
    BOOL mediatorServerInInitialQueueSend;
    BOOL doUnblockIncomingMessages;
    BOOL isWaitingForReconnect;
    BOOL isRolePromotedToLeader;

    dispatch_queue_t queueConnectionStateDelegate;
    NSMutableSet *clientConnectionStateDelegates;

    dispatch_queue_t queueMessageListenerDelegate;
    NSMutableSet *clientMessageListenerDelegates;

    dispatch_queue_t queueMessageProcessorDelegate;
    id<MessageProcessorDelegate> clientMessageProcessorDelegate;
    
    dispatch_queue_t queueTaskExecutionTransactionDelegate;
    id<TaskExecutionTransactionDelegate> clientTaskExecutionTransactionDelegate;
}

@synthesize backgroundEntityManagerForMessageProcessing;
@synthesize lastRtt;
@synthesize deviceGroupKeys;
@synthesize deviceID;
@synthesize isAppInBackground;

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

struct pktLogin {
    char identity[kIdentityLen];
    char client_version[kClientVersionLen];
    unsigned char server_cookie[kCookieLen];
    unsigned char reserved1[24]; // all-zero
    unsigned char vouch[kVouchLen];
    char reserved2[16]; // all-zero
};

struct pktLoginAck {
    char reserved[kLoginAckReservedLen];
};

struct pktPayload {
    uint8_t type;
    uint8_t reserved[3];
    char data[];
};

struct pktExtension {
    uint8_t type;
    uint16_t length;
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
#define TAG_PAYLOAD_MEDIATOR_TRIGGERED 8

#define EXTENSION_TYPE_CLIENT_INFO 0x00
#define EXTENSION_TYPE_DEVICE_ID 0x01
#define EXTENSION_TYPE_MESSAGE_PAYLOAD_VERSION 0x02
#define EXTENSION_TYPE_DEVICE_COOKIE 0x03

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
        sendPushTokenQueue = dispatch_queue_create("ch.threema.ServerConnector.sendPushTokenQueue", NULL);
        removeVoIPPushTokenQueue = dispatch_queue_create("ch.threema.ServerConnector.removeVoIPPushTokenQueue", NULL);
        isRemovedVoIPPushToken = NO;
        
        connectionInitiators = [[NSMutableArray alloc] init];

        socketQueue = dispatch_queue_create("ch.threema.ServerConnector.socketQueue", NULL);
        sendMessageQueue = dispatch_queue_create("ch.threema.ServerConnector.sendMessageQueue", NULL);
        disconnectCondition = [[NSCondition alloc] init];
        
        serverConnectorConnectionState = [[ServerConnectorConnectionState alloc]  initWithUserSettings:[UserSettings sharedUserSettings] connectionStateDelegate:self];
        reconnectAttempts = 0;
        lastSentEchoSeq = 0;
        lastRcvdEchoSeq = 0;

        displayedServerAlerts = [NSMutableSet set];
        
        /* register with reachability API */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStatusDidChange:) name:@"reachabilityChanged" object:nil];
        
        reachabilityWrapper = [[ReachabilityWrapper alloc] init];

        doUnblockIncomingMessages = YES;
        isWaitingForReconnect = NO;
        isRolePromotedToLeader = NO;
        
        /* listen for identity changes */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(identityCreated:) name:kNotificationCreatedIdentity object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(identityDestroyed:) name:kNotificationDestroyedIdentity object:nil];

        queueConnectionStateDelegate = dispatch_queue_create("ch.threema.ServerConnector.queueConnectionStateDelegate", NULL);
        queueMessageListenerDelegate = dispatch_queue_create("ch.threema.ServerConnector.queueMessageListenerDelegate", NULL);
        queueMessageProcessorDelegate = dispatch_queue_create("ch.threema.ServerConnector.queueMessageProcessorDelegate", NULL);
        queueTaskExecutionTransactionDelegate = dispatch_queue_create("ch.threema.ServerConnector.queueTaskExecutionTransactionDelegate", NULL);
    }
    return self;
}

#pragma mark - Register/unregister delegates for Message Listener, Message Processor and Task Manager transaction

- (void)registerConnectionStateDelegate:(id<ConnectionStateDelegate>)delegate {
    dispatch_sync(queueConnectionStateDelegate, ^{
        if (clientConnectionStateDelegates == nil) {
            clientConnectionStateDelegates = [NSMutableSet new];
        }
        if ([clientConnectionStateDelegates containsObject:delegate] == NO) {
            [clientConnectionStateDelegates addObject:delegate];
        }
    });
}

- (void)unregisterConnectionStateDelegate:(id<ConnectionStateDelegate>)delegate {
    dispatch_sync(queueConnectionStateDelegate, ^{
        if (clientConnectionStateDelegates != nil && [clientConnectionStateDelegates containsObject:delegate] == YES) {
            [clientConnectionStateDelegates removeObject:delegate];
        }
    });
}

- (void)registerMessageListenerDelegate:(id<MessageListenerDelegate>)delegate {
    dispatch_sync(queueMessageListenerDelegate, ^{
        if (clientMessageListenerDelegates == nil) {
            clientMessageListenerDelegates = [NSMutableSet new];
        }
        if ([clientMessageListenerDelegates containsObject:delegate] == NO) {
            [clientMessageListenerDelegates addObject:delegate];
        }
    });
}

- (void)unregisterMessageListenerDelegate:(id<MessageListenerDelegate>)delegate {
    dispatch_sync(queueMessageListenerDelegate, ^{
        if (clientMessageListenerDelegates != nil && [clientMessageListenerDelegates containsObject:delegate] == YES) {
            [clientMessageListenerDelegates removeObject:delegate];
        }
    });
}

- (void)registerMessageProcessorDelegate:(id<MessageProcessorDelegate>)delegate {
    dispatch_async(queueMessageProcessorDelegate, ^{
        if (delegate != nil) {
            clientMessageProcessorDelegate = delegate;
        }
    });
}

- (void)unregisterMessageProcessorDelegate:(id<MessageProcessorDelegate>)delegate {
    dispatch_async(queueMessageProcessorDelegate, ^{
        if ([delegate isEqual:clientMessageProcessorDelegate]) {
            clientMessageProcessorDelegate = nil;
        }
    });
}

- (void)registerTaskExecutionTransactionDelegate:(id<TaskExecutionTransactionDelegate>)delegate {
    dispatch_sync(queueTaskExecutionTransactionDelegate, ^{
        if (delegate != nil) {
            clientTaskExecutionTransactionDelegate = delegate;
        }
    });
}

- (void)unregisterTaskExecutionTransactionDelegate:(id<TaskExecutionTransactionDelegate>)delegate {
    dispatch_sync(queueTaskExecutionTransactionDelegate, ^{
        if ([delegate isEqual:clientTaskExecutionTransactionDelegate]) {
            clientTaskExecutionTransactionDelegate = nil;
        }
    });
}

#pragma mark - Chat (Mediator) Server connection handling

- (void)connect:(ConnectionInitiator)initiator {
    if ([[UserSettings sharedUserSettings] blockCommunication]) {
        DDLogNotice(@"Cannot connect - communication is blocked");
        return;
    }

    doUnblockIncomingMessages = YES;

    dispatch_async(socketQueue, ^{
        // TODO: Remove comment IOS-3558
        DDLogNotice(@"Entered socket queue in connect.");
        [self connectBy:initiator];
        // TODO: Remove comment IOS-3558
        DDLogNotice(@"ConnectBy finished.");

        lastErrorDisplay = nil;
        [self _connect];
        // TODO: Remove comment IOS-3558
        DDLogNotice(@"Left socket queue in connect.");
    });
}

- (void)connectWait:(ConnectionInitiator)initiator {
    if ([[UserSettings sharedUserSettings] blockCommunication]) {
        DDLogNotice(@"Cannot connect - communication is blocked");
        return;
    }

    doUnblockIncomingMessages = YES;

    dispatch_sync(socketQueue, ^{
        // TODO: Remove comment IOS-3558
        DDLogNotice(@"Entered socket queue in connectWait.");
        [self connectBy:initiator];
        // TODO: Remove comment IOS-3558
        DDLogNotice(@"ConnectBy finished.");

        lastErrorDisplay = nil;
        [self _connect];
        // TODO: Remove comment IOS-3558
        DDLogNotice(@"Left socket queue in connectWait.");
    });
}

- (void)connectWaitDoNotUnblockIncomingMessages:(ConnectionInitiator)initiator {
    doUnblockIncomingMessages = NO;

    dispatch_sync(socketQueue, ^{
        [self connectBy:initiator];

        lastErrorDisplay = nil;
        [self _connect];
    });
}

- (void)_connect {
    // TODO: Remove comment IOS-3558
    DDLogNotice(@"Connect began.");
    if (ProcessInfoHelper.isRunningForScreenshots)  {
        return;
    }

    if (!AppSetup.isIdentityProvisioned) {
        DDLogNotice(@"Cannot connect - identity not provisioned");
        return;
    }
    
    if (self.connectionState == ConnectionStateDisconnecting) {
        // TODO: Remove comment IOS-3558
        DDLogNotice(@"Connect: State was disconnecting.");
        if ([AppGroup getCurrentType] != AppGroupTypeNotificationExtension) {
            // The socketDidDisconnect callback has not been called yet; ensure that we reconnect
            // as soon as the previous disconnect has finished.
            reconnectAttempts = 1;
            autoReconnect = YES;
            return;
        }
    } else if (self.connectionState != ConnectionStateDisconnected) {
        if (self.connectionState == ConnectionStateConnecting
            || self.connectionState == ConnectionStateConnected
            || self.connectionState == ConnectionStateLoggedIn)
        {
            // TODO: Remove comment IOS-3558
            DDLogNotice(@"Connect: State was connecting, connected or logged in.");
            return;
        }

        DDLogNotice(@"Cannot connect - invalid connection state (actual state: %@)", [self nameForConnectionState:self.connectionState]);
        if ([AppGroup getCurrentType] != AppGroupTypeNotificationExtension) {
            autoReconnect = YES;
            [self reconnectAfterDelay];
            return;
        }
    }
    
    if ([AppGroup amIActive] == NO) {
        if ([AppGroup getCurrentType] != AppGroupTypeNotificationExtension) {
            DDLogNotice(@"Not active -> don't connect now, retry later");
            // keep delay at constant rate to avoid too long waits when becoming active again
            reconnectAttempts = 1;
            autoReconnect = YES;
            [self reconnectAfterDelay];
        }
        else {
            DDLogNotice(@"Not active -> disconnect now");
            [self _disconnect];
        }
        return;
    }

    LicenseStore *licenseStore = [LicenseStore sharedLicenseStore];
    if ([licenseStore isValid] == NO) {
        // TODO: Remove comment IOS-3558
        DDLogNotice(@"LicenseStore was invalid.");
        [licenseStore performLicenseCheckWithCompletion:^(BOOL success) {
            // TODO: Remove comment IOS-3558
            DDLogNotice(@"LicenseStore perform check.");
            if (success) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLicenseCheckSuccess object:nil];
                [self _connect];
            } else {
                // don't show license warning for connection errors
                DDLogNotice(@"License check failed: %@", licenseStore.error);
                if ([licenseStore.error.domain hasPrefix:@"NSURL"] == NO && licenseStore.error.code != 256) {                    
                    // License check failed permanently; need to inform user and ask for new license username/password
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLicenseMissing object:nil];
                }
                else if ([licenseStore.error.domain hasPrefix:@"NSURL"] == YES && licenseStore.error.code == -1009 && ![[LicenseStore sharedLicenseStore] isWithinOfflineInterval]) {
                    // License check failed because we don't have network connection. WithinCheckInterval for license failed, show license screen
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLicenseMissing object:nil];
                }
                else {
                    // License check failed due to connection error – try again later
                    // TODO: Remove comment IOS-3558
                    DDLogNotice(@"LicenseStore failed, reconnecting after delay.");
                    autoReconnect = YES;
                    [self reconnectAfterDelay];
                }
            }
        }];
        
        return;
    }

    [licenseStore performUpdateWorkInfo];

    [serverConnectorConnectionState connecting];
    autoReconnect = YES;
    self.lastRtt = -1;
    lastRead = CACurrentMediaTime();
    chatServerInInitialQueueSend = YES;
    mediatorServerInInitialQueueSend = YES;
    
    /* Reset nonces for new connection */
    clientNonce = 1;
    serverNonce = 1;
    
    /* Generate a new ephemeral key pair for the server connection. */
    NSData *publicKey, *secretKey;
    [[NaClCrypto sharedCrypto] generateKeyPairPublicKey:&publicKey secretKey:&secretKey];
    clientTempKeyPub = publicKey;
    clientTempKeySec = secretKey;
#if LOG_KEY_INFO
    DDLogVerbose(@"Client tempkey_pub = %@, tempkey_sec = %@", clientTempKeyPub, clientTempKeySec);
#endif

    DeviceGroupKeyManager *deviceGroupKeyManager = [[DeviceGroupKeyManager alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    NSData *dgk = deviceGroupKeyManager.dgk;
    if (!dgk) {
        DDLogNotice(@"Connect direct.");
        // TODO: Remove comment IOS-3558
        [self _connectDirect];
    } else {
        DDLogNotice(@"Connect mediator.");
        // TODO: Remove comment IOS-3558
        [self _connectViaMediator:dgk];
    }
}

- (void)_connectDirect {
    // TODO: Remove comment IOS-3558
    DDLogNotice(@"Connect direct started.");
    // Multi device is not activated, reset device group keys and device ID
    @synchronized (deviceGroupKeys) {
        deviceGroupKeys = nil;
        deviceID = nil;
    };

    // Obtain chat server host/ports/keys from ServerInfoProvider
    [[ServerInfoProviderFactory makeServerInfoProvider] chatServerWithIpv6:[UserSettings sharedUserSettings].enableIPv6 completionHandler:^(ChatServerInfo * _Nullable chatServerInfo, NSError *error) {
        // TODO: Remove comment IOS-3558
        DDLogNotice(@"ChatServerWithIpv6 started.");
        dispatch_async(socketQueue, ^{
            // TODO: Remove comment IOS-3558
            DDLogNotice(@"Connect direct socket queue entered.");
            if (chatServerInfo == nil) {
                // Could not get the info at the moment; try again later
                [serverConnectorConnectionState disconnected];
                [self reconnectAfterDelay];
                return;
            }
            
            NSString *serverHost;
            if (chatServerInfo.useServerGroups) {
                serverHost = [NSString stringWithFormat:@"%@%@%@", chatServerInfo.serverNamePrefix, [MyIdentityStore sharedMyIdentityStore].serverGroup, chatServerInfo.serverNameSuffix];
            } else {
                serverHost = chatServerInfo.serverNameSuffix;
            }
            
            serverKeyPub = chatServerInfo.publicKey;
            serverAltKeyPub = chatServerInfo.publicKeyAlt;
            
            UserSettings *settings = [UserSettings sharedUserSettings];

            NSError *socketError;
            socket = [[ChatTcpSocket alloc] initWithServer:serverHost ports:chatServerInfo.serverPorts preferIPv6:settings.enableIPv6 delegate:self queue:socketQueue error:&socketError];
            
            if (socketError != nil || ![socket connect]) {
                // TODO: Remove comment IOS-3558
                DDLogNotice(@"Connect direct error.");
                [serverConnectorConnectionState disconnected];
                [self reconnectAfterDelay];
                return;
            }
            // TODO: Remove comment IOS-3558
            DDLogNotice(@"Connect direct socket queue left.");
        });
    }];
}

- (void)_connectViaMediator:(nonnull NSData *)dgk {
    UserSettings *settings = [UserSettings sharedUserSettings];

    // Derive multi device keys
    NSError *deriveKeyError;
    DeviceGroupDerivedKey *deviceGroupDerivedKey = [[DeviceGroupDerivedKey alloc] initWithDgk:dgk error:&deriveKeyError];

    if (deriveKeyError) {
        DDLogError(@"Device Group Keys could not be derived");
        [serverConnectorConnectionState disconnected];
        [self reconnectAfterDelay];
        return;
    }

    // Multi device is activated, check device ID
    NSData *deviceGroupID;

    @synchronized (deviceGroupKeys) {
        deviceGroupID = [[NaClCrypto sharedCrypto] derivePublicKeyFromSecretKey:deviceGroupDerivedKey.dgpk];

        const unsigned char *deviceGroupIDBytes = [deviceGroupID bytes];
        NSString *deviceGroupIDFirstByteHex = [NSString stringWithFormat:@"%02lx", (unsigned long)deviceGroupIDBytes[0]];

        NSLog(@"%@", [NSString stringWithHexData:deviceGroupID]);
        deviceGroupKeys = [[DeviceGroupKeys alloc] initWithDgpk:deviceGroupDerivedKey.dgpk dgrk:deviceGroupDerivedKey.dgrk dgdik:deviceGroupDerivedKey.dgdik dgsddk:deviceGroupDerivedKey.dgsddk dgtsk:deviceGroupDerivedKey.dgtsk deviceGroupIDFirstByteHex:deviceGroupIDFirstByteHex];

        if ([settings deviceID] == nil || [[settings deviceID] length] != kDeviceIdLen) {
            settings.deviceID = [NSData dataWithBytes:[[NaClCrypto sharedCrypto] randomBytes:kDeviceIdLen].bytes length:kDeviceIdLen];
        }
        deviceID = settings.deviceID;
    };

    NSAssert([deviceID length] == kDeviceIdLen, @"Device ID has wrong length");

    NSString *clientUrlInfo = [MediatorMessageProtocol encodeClientURLInfoWithDgpkPublicKey:deviceGroupID serverGroup:[MyIdentityStore sharedMyIdentityStore].serverGroup];

    id<ServerInfoProvider> serverInfoProvider = [ServerInfoProviderFactory makeServerInfoProvider];
    [serverInfoProvider mediatorServerWithDeviceGroupIDFirstByteHex: deviceGroupKeys.deviceGroupIDFirstByteHex completionHandler:^(MediatorServerInfo * _Nullable mediatorServerInfo, NSError * _Nullable mediatorServerError) {
        // Obtain chat server info too (for public keys)
        [serverInfoProvider chatServerWithIpv6:[UserSettings sharedUserSettings].enableIPv6 completionHandler:^(ChatServerInfo * _Nullable chatServerInfo, NSError * _Nullable chatServerError) {
            if (mediatorServerInfo == nil || chatServerInfo == nil) {
                // Could not get the info at the moment; try again later
                [serverConnectorConnectionState disconnected];
                [self reconnectAfterDelay];
                return;
            }
            
            NSString *server = [NSString stringWithFormat:@"%@/%@", mediatorServerInfo.url, clientUrlInfo];
            serverKeyPub = chatServerInfo.publicKey;
            serverAltKeyPub = chatServerInfo.publicKeyAlt;
            
            NSError *socketError;
            socket = [[MediatorWebSocket alloc] initWithServer:server ports:@[] preferIPv6:settings.enableIPv6 delegate:self queue:socketQueue error:&socketError];
            
            if (socketError != nil || ![socket connect]) {
                [serverConnectorConnectionState disconnected];
                [self reconnectAfterDelay];
                return;
            }
        }];
    }];
}

- (void)_disconnect {
    if ([serverConnectorConnectionState connectionState] == ConnectionStateDisconnected) {
        return;
    }
    
    /* disconnect socket and make sure we don't reconnect */
    autoReconnect = NO;
    [serverConnectorConnectionState disconnecting];
    [socket disconnect];
}

- (void)disconnect:(ConnectionInitiator)initiator {
    dispatch_async(socketQueue, ^{
        if ([self isOthersConnectedDisconnectBy:initiator] == NO) {
            [self _disconnect];
        }
    });
}

- (BOOL)disconnectWait:(ConnectionInitiator)initiator {
    __block BOOL isDisconnected = NO;

    dispatch_sync(socketQueue, ^{
        if ([self isOthersConnectedDisconnectBy:initiator] == NO) {
            [self _disconnect];
            isDisconnected = YES;
        }
    });

    if (isDisconnected) {
        [serverConnectorConnectionState waitForStateDisconnected];
    }

    return isDisconnected;
}

- (void)reconnect {
    dispatch_async(socketQueue, ^{
        if ([serverConnectorConnectionState connectionState] == ConnectionStateDisconnected) {
            [self _connect];
        } else if ([serverConnectorConnectionState connectionState] == ConnectionStateConnecting) {
            DDLogVerbose(@"Connection already in progress, not reconnecting");
        } else {
            autoReconnect = YES;
            [serverConnectorConnectionState disconnecting];
            [socket disconnect];
        }
    });
}

- (ConnectionState)connectionState {
    return [serverConnectorConnectionState connectionState];
}

#pragma mark - Chat (Mediator) Server connection initiator handling

- (void)connectBy:(ConnectionInitiator)initiator {
    DDLogNotice(@"Connect initiated by (%@)", [self nameForConnectionInitiator:initiator]);
    if (![connectionInitiators containsObject:[NSNumber numberWithInteger:initiator]]) {
        // TODO: Remove comment IOS-3558
        DDLogNotice(@"Add initiator to connectInitiators.");
        [connectionInitiators addObject:[NSNumber numberWithInteger:initiator]];
    }
}

- (BOOL)isOthersConnectedDisconnectBy:(ConnectionInitiator)initiator {
    DDLogNotice(@"Disconnect initiated by (%@)", [self nameForConnectionInitiator:initiator]);
    [connectionInitiators removeObject:[NSNumber numberWithInteger:initiator]];
    if ([connectionInitiators count] != 0) {
        NSMutableString *initiators = [NSMutableString new];

        for (int i = 0; i < [connectionInitiators count]; i++) {
            ConnectionInitiator initiatorItem = (ConnectionInitiator)[(NSNumber *)[connectionInitiators objectAtIndex:i] intValue];
            if ([initiators length] > 0) {
                [initiators appendString:@", "];
            }
            [initiators appendString:[self nameForConnectionInitiator:initiatorItem]];
        }
        DDLogNotice(@"Do not disconnect because maybe others are still connected (%@)", initiators);
        return YES;
    }
    else {
        return NO;
    }
}

- (NSString *)nameForConnectionInitiator:(ConnectionInitiator)initiator {
    switch (initiator) {
        case ConnectionInitiatorApp:
            return @"App";
        case ConnectionInitiatorNotificationExtension:
            return @"NotificationExtension";
        case ConnectionInitiatorNotificationHandler:
            return @"NotificationHandler";
        case ConnectionInitiatorShareExtension:
            return @"ShareExtension";
        case ConnectionInitiatorThreemaCall:
            return @"ThreemaCall";
        case ConnectionInitiatorThreemaWeb:
            return @"ThreemaWeb";
        default:
            return nil;
    }
}

#pragma mark - Processing incoming payloads

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
            
            BOOL anotherConnectionError = false;
            
            if ([errorMessage rangeOfString:@"Another connection"].location != NSNotFound) {
                // extension took over connection
                if ([AppGroup amIActive] == NO) {
                    break;
                }
                
                anotherConnectionError = true;
                
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
                
                NSDictionary *info = nil;
                
                if (anotherConnectionError) {
                    NSBundle *bundle = [BundleUtil mainBundle];
                    errorMessage = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"error_other_connection_for_same_identity_message"], [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"]];
                    info = [NSDictionary dictionaryWithObjectsAndKeys: [BundleUtil localizedStringForKey:@"error_other_connection_for_same_identity_title"], kKeyTitle, errorMessage, kKeyMessage, nil];
                } else {
                    info = [NSDictionary dictionaryWithObjectsAndKeys: errorMessage, kKeyMessage, nil];
                }
                
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
            NSData *messageId = [NSData dataWithBytes:ack->message_id length:kMessageIdLen];
            NSString *toIdentity = [[NSString alloc] initWithData:[NSData dataWithBytes:ack->to_identity length:kIdentityLen] encoding:NSASCIIStringEncoding];
            [[NSNotificationCenter defaultCenter] postNotificationName:[TaskManager chatMessageAckObserverNameWithMessageID:messageId toIdentity:toIdentity] object:nil];
            break;
        }
        case PLTYPE_INCOMING_MESSAGE: {
            if (datalen <= sizeof(struct plMessage)) {
                DDLogError(@"Bad message payload datalen %d", datalen);
                [socket disconnect];
                break;
            }
            
            if ([AppGroup amIActive] && [AppGroup getCurrentType] != AppGroupTypeShareExtension) {
                struct plMessage *plmsg = (struct plMessage*)pl->data;
                int minlen = (sizeof(struct plMessage) + kNonceLen + plmsg->metadata_len + kNaClBoxOverhead + 1);
                if (datalen <= minlen || (plmsg->metadata_len > 0 && plmsg->metadata_len <= kNaClBoxOverhead)) {
                    DDLogError(@"Bad message payload datalen %d, metadata_len %d", datalen, plmsg->metadata_len);
                    [socket disconnect];
                    break;
                }
                
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
                if (plmsg->metadata_len > 0) {
                    boxmsg.metadataBox = [NSData dataWithBytes:&plmsg->metadata_nonce_box length:plmsg->metadata_len];
                }
                boxmsg.nonce = [NSData dataWithBytes:&plmsg->metadata_nonce_box[plmsg->metadata_len] length:kNonceLen];
                boxmsg.box = [NSData dataWithBytes:&plmsg->metadata_nonce_box[plmsg->metadata_len + kNonceLen] length:(datalen - sizeof(struct plMessage) - kNonceLen - plmsg->metadata_len)];

                // Set time out for downloading thumbnail to 5s, if the app in background or notification extension is running
                int timeoutDownloadThumbnail = isAppInBackground || [AppGroup getCurrentType] == AppGroupTypeNotificationExtension ? 5 : 0;

                TaskDefinitionReceiveMessage *task = [[TaskDefinitionReceiveMessage alloc] initWithMessage:boxmsg receivedAfterInitialQueueSend:!chatServerInInitialQueueSend maxBytesToDecrypt:[AppGroup getCurrentType] != AppGroupTypeNotificationExtension ? MAX_BYTES_TO_DECRYPT_NO_LIMIT : MAX_BYTES_TO_DECRYPT_NOTIFICATION_EXTENSION timeoutDownloadThumbnail:timeoutDownloadThumbnail];

                // Use `[self entityManagerForMessageProcessing]` if is not nil (properly setted from Notification Extension), otherwise nil (means will be created within TaskManager) for in App processing
                TaskManager *tm = [[TaskManager alloc] initWithBackgroundEntityManager:[self backgroundEntityManagerForMessageProcessing]];
                [tm addObjcWithTaskDefinition:task];
            }
            break;
        }
        case PLTYPE_QUEUE_SEND_COMPLETE:
            DDLogInfo(@"Queue send complete");
            chatServerInInitialQueueSend = NO;
            
            [self chatQueueDry];
             
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationQueueSendComplete object:nil userInfo:nil];
            break;
        case PLTYPE_DEVICE_COOKIE_CHANGE_INDICATION: {
            DDLogWarn(@"Got device cookie change indication");
            if ([DeviceCookieManager changeIndicationReceived]) {
                [self clearDeviceCookieChangedIndicator];
            }
            break;
        }
        default:
            DDLogWarn(@"Unsupported payload type %d", pl->type);
            break;
    }
}

- (void)completedProcessingAbstractMessage:(AbstractMessage *)msg {
    if (!(msg.flags.intValue & MESSAGE_FLAG_DONT_ACK)) {
        /* send ACK to server */
        [self ackMessage:msg.messageId fromIdentity:msg.fromIdentity];
    }
}

- (BOOL)completedProcessingMessage:(BoxedMessage *)boxmsg {
    if (!(boxmsg.flags & MESSAGE_FLAG_DONT_ACK)) {
        /* send ACK to server */
        return [self ackMessage:boxmsg.messageId fromIdentity:boxmsg.fromIdentity];
    }
    return YES;
}

- (void)reconnectAfterDelay {
    // Never reconnect for the notification extension
    if (!autoReconnect || [AppGroup getCurrentType] == AppGroupTypeNotificationExtension) {
        return;
    }
    
    /* calculate delay using bound exponential backoff */
    float reconnectDelay = powf(kReconnectBaseInterval, MIN(reconnectAttempts - 1, 10));
    if (reconnectDelay > kReconnectMaxInterval) {
        reconnectDelay = kReconnectMaxInterval;
    }
    
    if (!isWaitingForReconnect) {
        isWaitingForReconnect = true;
        reconnectAttempts++;
        DDLogNotice(@"Waiting %f seconds before reconnecting", reconnectDelay);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, reconnectDelay * NSEC_PER_SEC);
        dispatch_after(popTime, socketQueue, ^(void){
            isWaitingForReconnect = false;
            [self _connect];
        });
    }
}

- (BOOL)sendPayloadWithType:(uint8_t)type data:(NSData*)data {
    if ([serverConnectorConnectionState connectionState] != ConnectionStateLoggedIn) {
        DDLogVerbose(@"Cannot send payload - not logged in");
        return NO;
    }
    
    /* Make encrypted box */
    unsigned long pllen = sizeof(struct pktPayload) + data.length;
    struct pktPayload *pl = malloc(pllen);
    if (!pl) {
        return NO;
    }
    
    memset(pl, 0, pllen);
    
    pl->type = type;
    memcpy(pl->data, data.bytes, data.length);
    
    NSData *plData = [NSData dataWithBytesNoCopy:pl length:pllen];
    
    __block BOOL isSent = NO;
    
    // Gets next client nonce not before the message was sent
    dispatch_barrier_sync(sendMessageQueue, ^{
        NSData *nextClientNonce = [self nextClientNonce];
        NSData *plBox = [[NaClCrypto sharedCrypto] encryptData:plData withPublicKey:serverTempKeyPub signKey:clientTempKeySec nonce:nextClientNonce];
        if (plBox == nil) {
            DDLogError(@"Payload encryption failed!");
            isSent = NO;
        }
        else {
            /* prepend length - make one NSData object to pass to socket to ensure it is sent
               in a single TCP segment */
            uint16_t pktlen = plBox.length;
            
            if (pktlen > kMaxPktLen) {
                DDLogError(@"Packet is too big (%d) - cannot send", pktlen);
                isSent = NO;
            }
            else {
                NSMutableData *sendData = [NSMutableData dataWithCapacity:plBox.length + sizeof(uint16_t)];
                [sendData appendBytes:&pktlen length:sizeof(uint16_t)];
                [sendData appendData:plBox];
                
                [socket writeWithData:sendData tag:TAG_PAYLOAD_SENT];
                
                isSent = YES;
            }
        }
    });
    
    return isSent;
}

- (BOOL)sendMessage:(BoxedMessage*)message {
    unsigned long msglen = sizeof(struct plMessage) + message.metadataBox.length + message.nonce.length + message.box.length;
    struct plMessage *plmsg = malloc(msglen);
    if (!plmsg) {
        return NO;
    }
    
    DDLogInfo(@"Sending message from %@ to %@ (ID %@), metadata box length %lu, box length %lu", message.fromIdentity,
          message.toIdentity, message.messageId, (unsigned long)message.metadataBox.length, (unsigned long)message.box.length);
    
    memcpy(plmsg->from_identity, [message.fromIdentity dataUsingEncoding:NSASCIIStringEncoding].bytes, kIdentityLen);
    memcpy(plmsg->to_identity, [message.toIdentity dataUsingEncoding:NSASCIIStringEncoding].bytes, kIdentityLen);
    memcpy(plmsg->message_id, message.messageId.bytes, kMessageIdLen);
    // Timestamp is now in encrypted metadata, so we always send 0. This will then be set by the server.
    plmsg->date = 0;
    plmsg->flags = message.flags;
    plmsg->reserved = 0;
    plmsg->metadata_len = message.metadataBox.length;
    memset(plmsg->push_from_name, 0, kPushFromNameLen);
    if (message.pushFromName != nil) {
        NSData *encodedPushFromName = [ThreemaUtilityObjC truncatedUTF8String:message.pushFromName maxLength:kPushFromNameLen];
        strncpy(plmsg->push_from_name, encodedPushFromName.bytes, encodedPushFromName.length);
    }
    
    size_t offset = 0;
    if (message.metadataBox != nil) {
        memcpy(&plmsg->metadata_nonce_box[offset], message.metadataBox.bytes, message.metadataBox.length);
        offset += message.metadataBox.length;
    }
    memcpy(&plmsg->metadata_nonce_box[offset], message.nonce.bytes, message.nonce.length);
    offset += message.nonce.length;
    memcpy(&plmsg->metadata_nonce_box[offset], message.box.bytes, message.box.length);
    
    return [self sendPayloadWithType:PLTYPE_OUTGOING_MESSAGE data:[NSData dataWithBytesNoCopy:plmsg length:msglen]];
}

- (NSError * _Nullable)reflectMessage:(NSData *)message {

    if (message == nil) {
        return [ThreemaError threemaError:[NSString stringWithFormat:@"Bad message"] withCode:ThreemaProtocolErrorBadMessage];
    }
    
    if ([(NSObject*)socket isKindOfClass:[MediatorWebSocket class]] == NO) {
        return [ThreemaError threemaError:[NSString stringWithFormat:@"Not connected to mediator"] withCode:ThreemaProtocolErrorNotConnectedToMediator];
    }

    if ([serverConnectorConnectionState connectionState] != ConnectionStateLoggedIn) {
        return [ThreemaError threemaError:[NSString stringWithFormat:@"Not logged in"] withCode:ThreemaProtocolErrorNotLoggedIn];
    }

    [socket writeWithData:message];
    return nil;
}

- (BOOL)ackMessage:(NSData*)messageId fromIdentity:(NSString*)fromIdentity {
    int msglen = sizeof(struct plMessageAck);
    struct plMessageAck *plmsgack = malloc(msglen);
    if (!plmsgack)
        return NO;
    
    DDLogInfo(@"Sending ack for message ID %@ from %@", messageId, fromIdentity);
    
    memcpy(plmsgack->from_identity, [fromIdentity dataUsingEncoding:NSASCIIStringEncoding].bytes, kIdentityLen);
    memcpy(plmsgack->message_id, messageId.bytes, kMessageIdLen);
    
    return [self sendPayloadWithType:PLTYPE_INCOMING_MESSAGE_ACK data:[NSData dataWithBytesNoCopy:plmsgack length:msglen]];
}

- (void)ping {
    dispatch_async(socketQueue, ^{
        [self sendEchoRequest];
    });
}

- (void)sendEchoRequest {
    if ([serverConnectorConnectionState connectionState] != ConnectionStateLoggedIn)
        return;
    
    lastSentEchoSeq++;
    DDLogInfo(@"Sending echo request (seq %llu)", lastSentEchoSeq);
    
    lastEchoSendTime = CACurrentMediaTime();
    [self sendPayloadWithType:PLTYPE_ECHO_REQUEST data:[NSData dataWithBytes:&lastSentEchoSeq length:sizeof(lastSentEchoSeq)]];
    
    id<SocketProtocol> curSocket = socket;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kReadTimeout * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        if (curSocket == socket && lastRcvdEchoSeq < lastSentEchoSeq) {
            DDLogInfo(@"No reply to echo payload; disconnecting");
            [socket disconnect];
        }
    });
}

#pragma mark - Multi Device

- (BOOL)isMultiDeviceActivated {
    @synchronized (deviceGroupKeys) {
        return deviceGroupKeys != nil && deviceID != nil;
    }
}

- (void)deactivateMultiDevice {
    @synchronized (deviceGroupKeys) {
        DeviceGroupKeyManager *deviceGroupKeyManager = [[DeviceGroupKeyManager alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
        [deviceGroupKeyManager destroy];
        [UserSettings sharedUserSettings].enableMultiDevice = NO;
        // Ensure that the change is observed by SettingStores
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSettingStoreSynchronization object:nil];
        deviceGroupKeys = nil;
        deviceID = nil;
    };
}

#pragma mark - Push Notification

- (BOOL)shouldRegisterPush {
    return [serverConnectorConnectionState connectionState] == ConnectionStateLoggedIn;
}

- (void)setPushToken:(NSData *)pushToken {
    [[AppGroup userDefaults] setObject:pushToken forKey:kPushNotificationDeviceToken];
    [[AppGroup userDefaults] synchronize];
    [self sendPushToken];
}

- (void)sendPushToken {
    dispatch_sync(sendPushTokenQueue, ^{
        NSData *pushToken = [[AppGroup userDefaults] objectForKey:kPushNotificationDeviceToken];
        
        if ([self shouldRegisterPush] == NO || pushToken == nil) {
            return;
        }

        DDLogInfo(@"Sending push notification token (apple mc)");
        
#ifdef DEBUG
        uint8_t pushTokenType = PUSHTOKEN_TYPE_APPLE_SANDBOX_MC;
#else
        uint8_t pushTokenType = PUSHTOKEN_TYPE_APPLE_PROD_MC;
#endif
        
        NSMutableData *payloadData = [NSMutableData dataWithBytes:&pushTokenType length:1];
        [payloadData appendData:pushToken];
        [payloadData appendData:[@"|" dataUsingEncoding:NSUTF8StringEncoding]];
        [payloadData appendData:[[BundleUtil threemaAppIdentifier] dataUsingEncoding:NSASCIIStringEncoding]];
        [payloadData appendData:[@"|" dataUsingEncoding:NSUTF8StringEncoding]];
        [payloadData appendData:[PushPayloadDecryptor pushEncryptionKey]];
        [self sendPayloadWithType:PLTYPE_PUSH_NOTIFICATION_TOKEN data:payloadData];
    });
}

- (void)removePushToken {
    dispatch_sync(sendPushTokenQueue, ^{
        if ([[AppGroup userDefaults] objectForKey:kPushNotificationDeviceToken] != nil) {
            [[AppGroup userDefaults] setObject:nil forKey:kPushNotificationDeviceToken];
            [[AppGroup userDefaults] synchronize];
        }
        else {
            DDLogInfo(@"Already removed push notification token (apple mc)");
            return;
        }
        
        if ([self shouldRegisterPush] == NO) {
            return;
        }

        DDLogInfo(@"Clearing push notification token (apple mc)");

        uint8_t pushTokenType = PUSHTOKEN_TYPE_NONE;
        NSData *payloadData = [NSData dataWithBytes:&pushTokenType length:1];
        [self sendPayloadWithType:PLTYPE_PUSH_NOTIFICATION_TOKEN data:payloadData];
    });
}

- (void)removeVoIPPushToken {
    dispatch_sync(removeVoIPPushTokenQueue, ^{
        
        if (isRemovedVoIPPushToken == YES) {
            DDLogInfo(@"Already removed VoIP push token (apple)");
            return;
        }

        if([[AppGroup userDefaults] objectForKey:kVoIPPushNotificationDeviceToken] != nil) {
            [[AppGroup userDefaults] setObject:nil forKey:kVoIPPushNotificationDeviceToken];
            [[AppGroup userDefaults] synchronize];
        }
 
        if ([self shouldRegisterPush] == NO) {
            return;
        }
        
        DDLogInfo(@"Clearing VoIP push token (apple)");
        
        uint8_t voIPPushTokenType = PUSHTOKEN_TYPE_NONE;
        NSData *payloadData = [NSData dataWithBytes:&voIPPushTokenType length:1];
        [self sendPayloadWithType:PLTYPE_VOIP_PUSH_NOTIFICATION_TOKEN data:payloadData];
        
        isRemovedVoIPPushToken = YES;
    });
}

- (void)clearDeviceCookieChangedIndicator {
    [self sendPayloadWithType:PLTYPE_CLEAR_DEVICE_COOKIE_CHANGE_INDICATION data:[NSData data]];
}

#pragma mark - Nonces and encryption

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

- (NSData *)encryptData:(NSData *)message key:(NSData *)key {
    if (message == nil) {
        return nil;
    }
    
    NSData *nonce = [[NaClCrypto sharedCrypto] randomBytes:kNonceLen];
    NSData *encryptedMessage = [[NaClCrypto sharedCrypto] symmetricEncryptData:message withKey:key nonce:nonce];

    NSMutableData *encryptedData = [[NSMutableData alloc] initWithData:nonce];
    [encryptedData appendData:encryptedMessage];
    
    return encryptedData;
}

#pragma mark - Connection state

- (NSString *)nameForConnectionState:(ConnectionState)state {
    return [serverConnectorConnectionState nameForConnectionState:state];
}

- (BOOL)isIPv6Connection {
    return [socket isIPv6];
}

- (BOOL)isProxyConnection {
    return [socket isProxyConnection];
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
    if ([reachabilityWrapper didLastConnectionTypeChange]) {
        if ([AppGroup getCurrentType] != AppGroupTypeNotificationExtension) {
            DDLogNotice(@"Internet status changed - forcing reconnect");
            [self reconnect];
        }
        else {
            DDLogNotice(@"Internet status changed - disconnect Notification Extension");
            [serverConnectorConnectionState disconnecting];
            [socket disconnect];
        }
    }
}

#pragma mark - SocketProtocolDelegate

- (void)didConnect {
    [serverConnectorConnectionState connected];

    /* Send client hello packet with temporary public key and client cookie */
    clientCookie = [[NaClCrypto sharedCrypto] randomBytes:kCookieLen];
    DDLogVerbose(@"Client cookie = %@", clientCookie);
    
    /* Make sure to pass everything in one writeData call, or we will get two separate TCP segments */
    struct pktClientHello clientHello;
    memcpy(clientHello.client_tempkey_pub, clientTempKeyPub.bytes, sizeof(clientHello.client_tempkey_pub));
    memcpy(clientHello.client_cookie, clientCookie.bytes, sizeof(clientHello.client_cookie));
    [socket writeWithData:[NSData dataWithBytes:&clientHello length:sizeof(clientHello)] tag:TAG_CLIENT_HELLO_SENT];
    
    /* Prepare to receive server hello packet */
    [socket readWithLength:sizeof(struct pktServerHello) timeout:kReadTimeout tag:TAG_SERVER_HELLO_READ];
}

- (void)didDisconnectWithErrorCode:(NSInteger)code {
    [serverConnectorConnectionState disconnected];

    DDLogWarn(@"Flushing incoming and interrupt outgoing queue on Task Manager");
    [TaskManager flushWithQueueType:TaskQueueTypeIncoming];
    [TaskManager interruptWithQueueType:TaskQueueTypeOutgoing];

    isRolePromotedToLeader = NO;

    if (keepalive_timer != nil) {
        dispatch_source_cancel(keepalive_timer);
        keepalive_timer = nil;
    }

    if (code == ServerConnectionCloseCodeUnsupportedProtocolVersion) {
        [self displayServerAlert:[BundleUtil localizedStringForKey:@"multi_device_unsupported_protocol_version_alert"]];
    }
    else if (code == ServerConnectionCloseCodeDeviceSlotStateMismatch) {
        [self displayServerAlert:[BundleUtil localizedStringForKey:@"multi_device_slot_state_mismatch_alert"]];

        // Device slot state mismatch -> this device must relink
        [self deactivateMultiDevice];
    }
    else {
        [self reconnectAfterDelay];
    }
}

- (void)didReadData:(NSData * _Nonnull)data tag:(int16_t)tag {
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
            
            /* prepare extension packet */
            NSMutableData *extensionsData = [NSMutableData data];
            
            /* client info (0x00) extension payload */
            NSData *clientVersion = [ThreemaUtility.clientVersion dataUsingEncoding:NSASCIIStringEncoding];
            [extensionsData appendData:[self makeExtensionWithType:EXTENSION_TYPE_CLIENT_INFO data:clientVersion]];
            
            /* message payload version (0x02) extension payload */
            uint8_t plv = 0x01;
            [extensionsData appendData:[self makeExtensionWithType:EXTENSION_TYPE_MESSAGE_PAYLOAD_VERSION data:[NSData dataWithBytes:&plv length:1]]];
            
            // Adding Device ID extension if is Multi Device activated
            if (deviceID != nil && [deviceID length] == kDeviceIdLen) {
                /* CSP device ID (0x01) extension payload */
                [extensionsData appendData:[self makeExtensionWithType:EXTENSION_TYPE_DEVICE_ID data:[UserSettings sharedUserSettings].deviceID]];
            }
            
            /* device cookie (0x03) extension payload */
            NSData *deviceCookie = [DeviceCookieManager obtainDeviceCookie];
            if (deviceCookie == nil) {
                DDLogError(@"Could not obtain device cookie");
                [socket disconnect];
                return;
            }
            [extensionsData appendData:[self makeExtensionWithType:EXTENSION_TYPE_DEVICE_COOKIE data:deviceCookie]];

            NSData *loginNonce = [self nextClientNonce];
            NSData *extensionsNonce = [self nextClientNonce];
            NSData *extensionsBox = [[NaClCrypto sharedCrypto] encryptData:extensionsData withPublicKey:serverTempKeyPub signKey:clientTempKeySec nonce:extensionsNonce];
            
            /* now prepare login packet */
            struct pktLogin login;
            memset(&login, 0, sizeof(struct pktLogin));
            
            memcpy(login.identity, [[MyIdentityStore sharedMyIdentityStore].identity dataUsingEncoding:NSASCIIStringEncoding].bytes, kIdentityLen);
            
            memcpy(login.client_version, "threema-clever-extension-field", 30);
            uint16_t extLen = extensionsBox.length;
            memcpy(&login.client_version[30], &extLen, sizeof(uint16_t));
            
            memcpy(login.server_cookie, serverCookie.bytes, kCookieLen);
            
            /* vouch calculation */
            NSMutableData *sharedSecrets = [NSMutableData dataWithData:[[MyIdentityStore sharedMyIdentityStore] sharedSecretWithPublicKey:chosenServerKeyPub]];
            [sharedSecrets appendData:[[MyIdentityStore sharedMyIdentityStore] sharedSecretWithPublicKey:serverTempKeyPub]];
            NSMutableData *vouchInput = [NSMutableData dataWithData:serverCookie];
            [vouchInput appendData:clientTempKeyPub];
            ThreemaKDF *kdf = [[ThreemaKDF alloc] initWithPersonal:@"3ma-csp"];
            NSData *vouchKey = [kdf deriveKeyWithSalt:@"v2" key:sharedSecrets];
            NSData *vouch = [ThreemaKDF calculateMacWithKey:vouchKey input:vouchInput];
            memcpy(login.vouch, vouch.bytes, kVouchLen);
                        
            /* encrypt login packet */
            NSData *loginBox = [[NaClCrypto sharedCrypto] encryptData:[NSData dataWithBytes:&login length:sizeof(login)] withPublicKey:serverTempKeyPub signKey:clientTempKeySec nonce:loginNonce];
            
            /* send it! */
            [socket writeWithData:loginBox tag:0];
            [socket writeWithData:extensionsBox tag:TAG_LOGIN_SENT];
            
            /* Prepare to receive login ack packet */
            [socket readWithLength:sizeof(struct pktLoginAck) + kNaClBoxOverhead timeout:kReadTimeout tag:TAG_LOGIN_ACK_READ];
            
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
            [serverConnectorConnectionState loggedInChatServer];

            [self sendPushToken];
            
            // Remove VoIP push token (since min OS version is iOS 15 or above)
            [self removeVoIPPushToken];

            /* Schedule task for keepalive */
            keepalive_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, socketQueue);
            dispatch_source_set_event_handler(keepalive_timer, ^{
                [self sendEchoRequest];
            });
            dispatch_source_set_timer(keepalive_timer, dispatch_time(DISPATCH_TIME_NOW, kKeepAliveInterval * NSEC_PER_SEC),
                                      kKeepAliveInterval * NSEC_PER_SEC, NSEC_PER_SEC);
            dispatch_resume(keepalive_timer);
            
            /* Unblock incoming messages if not running multi device or already promoted to leader */
            if (doUnblockIncomingMessages && (deviceID == nil || [deviceID length] != kDeviceIdLen || isRolePromotedToLeader)) {
                [self sendPayloadWithType:PLTYPE_UNBLOCK_INCOMING_MESSAGES data:[NSData data]];
            }
            
            /* Receive next payload header */
            [socket readWithLength:sizeof(uint16_t) timeout:-1 tag:TAG_PAYLOAD_LENGTH_READ];
            
            // Process all tasks
            TaskManager *tm = [[TaskManager alloc] init];
            [tm spool];
            
            break;
        }
            
        case TAG_PAYLOAD_LENGTH_READ: {
            uint16_t msglen = *((uint16_t*)data.bytes);
            [socket readWithLength:msglen timeout:-1 tag:TAG_PAYLOAD_READ];
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
            [socket readWithLength:sizeof(uint16_t) timeout:-1 tag:TAG_PAYLOAD_LENGTH_READ];
            
            break;
        }
            
        case TAG_PAYLOAD_MEDIATOR_TRIGGERED: {
            int timeoutDownloadThumbnail = isAppInBackground || [AppGroup getCurrentType] == AppGroupTypeNotificationExtension ? 20 : 0;

            TaskManager *taskManager = [[TaskManager alloc] init];

            MediatorMessageProcessor *processor = [[MediatorMessageProcessor alloc]
                                                   initWithDeviceGroupKeys:deviceGroupKeys
                                                   deviceID:deviceID
                                                   maxBytesToDecrypt:[AppGroup getCurrentType] != AppGroupTypeNotificationExtension ? MAX_BYTES_TO_DECRYPT_NO_LIMIT : MAX_BYTES_TO_DECRYPT_NOTIFICATION_EXTENSION
                                                   timeoutDownloadThumbnail:timeoutDownloadThumbnail
                                                   mediatorMessageProtocol:[[MediatorMessageProtocol alloc] initWithDeviceGroupKeys:deviceGroupKeys]
                                                   userSettings:[UserSettings sharedUserSettings]
                                                   taskManager:taskManager
                                                   socketProtocolDelegate:self
                                                   messageProcessorDelegate:self];

            uint8_t type;
            NSData *result = [processor processWithMessage:data messageType:&type receivedAfterInitialQueueSend:!mediatorServerInInitialQueueSend];

            if (result != nil && (int)type == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_REFLECT_ACK) {
                [[NSNotificationCenter defaultCenter] postNotificationName:[TaskManager mediatorMessageAckObserverNameWithReflectID:result] object:result];
            }
            else if ((int)type == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_LOCK_ACK || (int)type == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_UNLOCK_ACK || (int)type == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_TRANSACTION_REJECT) {
                [self transactionResponse:type reason:result];
            }
            else if ((int)type == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_TRANSACTION_ENDED) {
                [taskManager spool];
            }
            else if (result != nil && (int)type == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_SERVER_HELLO) {
                DDLogInfo(@"Send server hello to mediator");
                [socket writeWithData:result];
            }
            else if ((int)type == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_SERVER_INFO) {
                DDLogInfo(@"Got mediator server info; client connected");
                [serverConnectorConnectionState loggedInMediatorServer];
            }
            else if ((int)type == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_REFLECTION_QUEUE_DRY) {
                mediatorServerInInitialQueueSend = NO;
            }
            else if ((int)type == MediatorMessageProtocol.MEDIATOR_MESSAGE_TYPE_ROLE_PROMOTED_TO_LEADER) {
                DDLogVerbose(@"Promoted to leader -> unblock incoming chat messages");

                if ([serverConnectorConnectionState connectionState] == ConnectionStateLoggedIn) {
                    /* Unblock incoming messages */
                    [self sendPayloadWithType:PLTYPE_UNBLOCK_INCOMING_MESSAGES data:[NSData data]];

                    /* Receive next payload header */
                    [socket readWithLength:sizeof(uint16_t) timeout:-1 tag:TAG_PAYLOAD_LENGTH_READ];
                }
                else {
                    // Queue message and send it when logged in
                    // Unblock incoming messages as soon as we're logged in
                    isRolePromotedToLeader = YES;
                }
            }
            else if (result != nil) {
                [self messageReceived:type data:result];
            }

            break;
        }
    }
}

- (NSData*)makeExtensionWithType:(uint8_t)type data:(NSData*)data {
    struct pktExtension *extension = malloc(sizeof(struct pktExtension) + data.length);
    if (!extension) {
        return nil;
    }
    extension->type = type;
    extension->length = data.length;
    memcpy(extension->data, data.bytes, data.length);
    return [NSData dataWithBytesNoCopy:extension length:(sizeof(struct pktExtension) + data.length) freeWhenDone:YES];
}

#pragma mark - ConnectionStateDelegate

- (void)connectionStateChanged:(ConnectionState)state {
    dispatch_sync(queueConnectionStateDelegate, ^{
        if (clientConnectionStateDelegates != nil && [clientConnectionStateDelegates count] > 0) {
            for (id<ConnectionStateDelegate> delegate in clientConnectionStateDelegates) {
                [delegate connectionStateChanged:state];
            }
        }
    });
}

#pragma mark - MessageListenerDelegate

- (void)messageReceived:(uint8_t)type data:(NSData * _Nonnull)data {
    dispatch_sync(queueMessageListenerDelegate, ^{
        if (clientMessageListenerDelegates != nil && [clientMessageListenerDelegates count] > 0) {
            for (id<MessageListenerDelegate> clientListener in clientMessageListenerDelegates) {
                [clientListener messageReceived:clientListener type:type data:data];
            }
        }
    });
}

#pragma mark - MessageProcessorDelegate

- (void)beforeDecode {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate beforeDecode];
    });
}

- (void)changedManagedObjectID:(NSManagedObjectID *)objectID {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate changedManagedObjectID:objectID];
    });
}

- (void)incomingMessageStarted:(AbstractMessage * _Nonnull)message {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate incomingMessageStarted:message];
    });
}

- (void)incomingMessageChanged:(BaseMessage * _Nonnull)message fromIdentity:(NSString * _Nonnull)fromIdentity {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate incomingMessageChanged:message fromIdentity:fromIdentity];
    });
}

- (void)incomingMessageFinished:(AbstractMessage * _Nonnull)message {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate incomingMessageFinished:message];
    });
}

- (void)incomingMessageFailed:(BoxedMessage *)message {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate incomingMessageFailed:message];
    });
}

- (void)incomingAbstractMessageFailed:(AbstractMessage *)message {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate incomingAbstractMessageFailed:message];
    });
}

- (void)readMessage:(NSSet *)inConversations {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate readMessage:inConversations];
    });
}

- (void)taskQueueEmpty:(NSString * _Nonnull)queueTypeName {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate taskQueueEmpty:queueTypeName];
    });
}

- (void)chatQueueDry {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate chatQueueDry];
    });
}

- (void)reflectionQueueDry {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate reflectionQueueDry];
    });
}

- (void)processTypingIndicator:(TypingIndicatorMessage * _Nonnull)message {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate processTypingIndicator:message];
    });
}

- (void)processVoIPCall:(NSObject *)message identity:(NSString *)identity onCompletion:(void (^)(id<MessageProcessorDelegate> _Nonnull))onCompletion {
    dispatch_async(queueMessageProcessorDelegate, ^{
        [clientMessageProcessorDelegate processVoIPCall:message identity:identity onCompletion:onCompletion];
    });
}

#pragma mark - TaskExecutionTransactionDelegate

- (void)transactionResponse:(uint8_t)messageType reason:(NSData * _Nullable)reason {
    dispatch_sync(queueTaskExecutionTransactionDelegate, ^{
        [clientTaskExecutionTransactionDelegate transactionResponse:messageType reason:reason];
    });
}

#pragma mark - Notifications

- (void)identityCreated:(NSNotification*)notification {
    /* when the identity is created, we should connect */
    dispatch_async(socketQueue, ^{
        [self connectBy:ConnectionInitiatorApp];
        [self _connect];
    });
}

- (void)identityDestroyed:(NSNotification*)notification {
    /* when the identity is destroyed, we must disconnect */
    if ([serverConnectorConnectionState connectionState] != ConnectionStateDisconnected) {
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
        
        [self _disconnect];
    }

    /* also flush the queue so that messages stuck in it don't later cause problems
       because they have the wrong from identity */
    DDLogWarn(@"Flushing incoming and outgoing queue on Task Manager");
    [TaskManager flushWithQueueType:TaskQueueTypeIncoming];
    [TaskManager flushWithQueueType:TaskQueueTypeOutgoing];
}

@end
