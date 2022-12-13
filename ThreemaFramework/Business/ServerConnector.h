//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

@class BoxedMessage;

typedef NS_CLOSED_ENUM(NSInteger, ConnectionInitiator) {
    ConnectionInitiatorApp,
    ConnectionInitiatorNotificationExtension,
    ConnectionInitiatorShareExtension,
    ConnectionInitiatorNotificationHandler,
    ConnectionInitiatorThreemaCall,
    ConnectionInitiatorThreemaWeb
};

@protocol ServerConnectorProtocol <NSObject, ConnectionStateDelegate, MessageListenerDelegate, MessageProcessorDelegate, TaskExecutionTransactionDelegate>

/**
 BusinessInjector for incoming message processor, will be set by Notification Extension to use the same background DB context
 */
@property (nonatomic, readwrite) NSObject *businessInjectorForMessageProcessing;

@property (nonatomic, readonly) ConnectionState connectionState;

@property (nonatomic, readonly) NSData *deviceGroupPathKey;

@property (nonatomic, readonly) BOOL isMultiDeviceActivated;

/**
 Encrypted device ID for chat server (CleVer extension).
 */
@property (nonatomic, readonly) NSData *deviceId NS_SWIFT_NAME(deviceID);

@property (nonatomic, readwrite) BOOL isAppInBackground;

- (void)connect:(ConnectionInitiator)initiator NS_SWIFT_NAME(connect(initiator:));
- (void)connectWait:(ConnectionInitiator)initiator NS_SWIFT_NAME(connectWait(initiator:));
- (void)disconnect:(ConnectionInitiator)initiator NS_SWIFT_NAME(disconnect(initiator:));

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
 
 @warning `deviceGroupPathKey` must not be `nil`
 
 @param message Message to reflect, if is not `nil`
 */
- (BOOL)reflectMessage:(NSData*)message;

- (BOOL)sendMessage:(BoxedMessage*)message;

- (BOOL)completedProcessingMessage:(BoxedMessage *)boxmsg;
- (void)failedProcessingMessage:(BoxedMessage *)boxmsg error:(NSError *)err;

@end

@interface ServerConnector : NSObject <ServerConnectorProtocol, SocketProtocolDelegate>

@property (nonatomic, readwrite) double lastRtt;
@property (nonatomic, readonly) BOOL isIPv6Connection;
@property (nonatomic, readonly) BOOL isProxyConnection;

+ (ServerConnector*)sharedServerConnector;

/**
 Wait (max. 3s) for connection state disconnected.

 @param initiator: Calling initiator of disconnect
 */
- (void)disconnectWait:(ConnectionInitiator)initiator NS_SWIFT_NAME(disconnectWait(initiator:));

- (void)reconnect;
- (NSString*)nameForConnectionState:(ConnectionState)connectionState;

- (void)completedProcessingAbstractMessage:(AbstractMessage *)msg;
- (void)ping;

/**
 Set Push Notification Token and send push type apple mc, for receiving Push Notifications in Notification Extension.
 
 @param pushToken Token from registration of Apple Notification Service
 */
- (void)setPushToken:(NSData *)pushToken;
- (void)removePushToken;

/**
 Set Voip Push Notification and send it as type of apple, for receiving Voip Push Notifications.
 
 @param voIPPushToken Token from PKPushRegistry registration with PushKit
 */
- (void)setVoIPPushToken:(NSData *)voIPPushToken;
- (void)removeVoIPPushToken;

- (void)sendPushAllowedIdentities;

@end
