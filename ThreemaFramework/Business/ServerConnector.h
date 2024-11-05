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

#import <Foundation/Foundation.h>
#import "ConnectionStateDelegate.h"
#import "MessageListenerDelegate.h"
#import "MessageProcessorDelegate.h"
#import "TaskExecutionTransactionDelegate.h"
#import "SocketProtocolDelegate.h"
#import "AbstractGroupMessage.h"
#import "DeviceGroupKeys.h"

@class BoxedMessage;

typedef NS_CLOSED_ENUM(NSInteger, ConnectionInitiator) {
    ConnectionInitiatorApp,
    ConnectionInitiatorNotificationExtension,
    ConnectionInitiatorShareExtension,
    ConnectionInitiatorNotificationHandler,
    ConnectionInitiatorThreemaCall,
    ConnectionInitiatorThreemaWeb
};

NS_ASSUME_NONNULL_BEGIN

@protocol ServerConnectorProtocol <NSObject, ConnectionStateDelegate, MessageListenerDelegate, MessageProcessorDelegate, TaskExecutionTransactionDelegate>

/**
 BusinessInjector for incoming message processor, will be set by Notification Extension to use the same background DB context
 */
@property (nonatomic, readwrite, assign, nullable) NSObject *backgroundEntityManagerForMessageProcessing;

@property (nonatomic, readonly) ConnectionState connectionState;

@property (nonatomic, readonly, nullable) DeviceGroupKeys *deviceGroupKeys;

/**
 Encrypted device ID for chat server (CleVer extension).
 */
@property (nonatomic, readonly, nullable) NSData *deviceID;

/// Maximum number of linked devices allowed including this device. This is only set if multi-device is enabled and logged in to mediator
@property (nonatomic, readonly, nullable) NSNumber *maximumNumberOfDeviceSlots;

@property (nonatomic, readwrite) BOOL isAppInBackground;

- (void)connect:(ConnectionInitiator)initiator NS_SWIFT_NAME(connect(initiator:));
- (void)connectWait:(ConnectionInitiator)initiator NS_SWIFT_NAME(connectWait(initiator:));
- (void)connectWaitDoNotUnblockIncomingMessages:(ConnectionInitiator)initiator NS_SWIFT_NAME(connectWaitDoNotUnblockIncomingMessages(initiator:));
/// Unblock receiving incoming messages
- (void)unblockIncomingMessages;

- (void)disconnect:(ConnectionInitiator)initiator NS_SWIFT_NAME(disconnect(initiator:));

/**
 Wait (max. 3s) for connection state disconnected.

 @param initiator: Calling initiator of disconnect
 @return BOOL is YES if disconnected
 */
- (BOOL)disconnectWait:(ConnectionInitiator)initiator NS_SWIFT_NAME(disconnectWait(initiator:));
 
- (void)reconnect;

- (NSString*)nameForConnectionState:(ConnectionState)connectionState;

- (void)deactivateMultiDevice;

- (void)registerConnectionStateDelegate:(id<ConnectionStateDelegate>)delegate NS_SWIFT_NAME(registerConnectionStateDelegate(delegate:));
- (void)unregisterConnectionStateDelegate:(id<ConnectionStateDelegate>)delegate NS_SWIFT_NAME(unregisterConnectionStateDelegate(delegate:));

- (void)registerMessageListenerDelegate:(id<MessageListenerDelegate>)delegate NS_SWIFT_NAME(registerMessageListenerDelegate(delegate:));
- (void)unregisterMessageListenerDelegate:(id<MessageListenerDelegate>)delegate NS_SWIFT_NAME(unregisterMessageListenerDelegate(delegate:));

- (void)registerMessageProcessorDelegate:(id<MessageProcessorDelegate>)delegate NS_SWIFT_NAME(registerMessageProcessorDelegate(delegate:));
- (void)unregisterMessageProcessorDelegate:(id<MessageProcessorDelegate>)delegate NS_SWIFT_NAME(unregisterMessageProcessorDelegate(delegate:));

- (void)registerTaskExecutionTransactionDelegate:(id<TaskExecutionTransactionDelegate>)delegate NS_SWIFT_NAME(registerTaskExecutionTransactionDelegate(delegate:));
- (void)unregisterTaskExecutionTransactionDelegate:(id<TaskExecutionTransactionDelegate>)delegate NS_SWIFT_NAME(unregisterTaskExecutionTransactionDelegate(delegate:));

/**
 Reflect message to Mediator server, only if Multi Device is activated.
 
 @warning Must be connected with mediator

 @param message Message to reflect, if is not `nil`
 @returns ThreemaError
 */
- (NSError * _Nullable)reflectMessage:(NSData*)message;

- (BOOL)sendMessage:(BoxedMessage*)message;

- (BOOL)completedProcessingMessage:(BoxedMessage *)boxmsg;

@end

@interface ServerConnector : NSObject <ServerConnectorProtocol, SocketProtocolDelegate>

@property (nonatomic, readwrite) double lastRtt;
@property (nonatomic, readonly) BOOL isIPv6Connection;
@property (nonatomic, readonly) BOOL isProxyConnection;

+ (ServerConnector*)sharedServerConnector;
- (instancetype) __unavailable init;

- (void)completedProcessingAbstractMessage:(AbstractMessage *)msg;
- (void)ping;

/**
 Set Push Notification Token and send push type apple mc, for receiving Push Notifications in Notification Extension.
 
 @param pushToken Token from registration of Apple Notification Service
 */
- (void)setPushToken:(NSData *)pushToken;

- (void)removePushToken;

- (void)removeVoIPPushToken;

- (void)clearDeviceCookieChangedIndicator;

@end

NS_ASSUME_NONNULL_END
