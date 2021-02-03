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

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "NaClCrypto.h"
#import "AbstractGroupMessage.h"

@class BoxedMessage;

@interface ServerConnector : NSObject <GCDAsyncSocketDelegate>

enum ConnectionState {
    ConnectionStateDisconnected = 1,
    ConnectionStateConnecting,
    ConnectionStateConnected,
    ConnectionStateLoggedIn,
    ConnectionStateDisconnecting
};

@property (nonatomic, readwrite) enum ConnectionState connectionState;
@property (nonatomic, readwrite) double lastRtt;
@property (nonatomic, readonly) BOOL isIPv6Connection;
@property (nonatomic, readonly) BOOL isProxyConnection;

+ (ServerConnector*)sharedServerConnector;

- (void)connect;
- (void)connectWait;
- (void)disconnect;
- (void)disconnectWait;
- (void)reconnect;
- (NSString*)nameForConnectionState:(enum ConnectionState)connectionState;
- (void)sendMessage:(BoxedMessage*)message;
- (void)ackMessage:(NSData*)messageId fromIdentity:(NSString*)fromIdentity;
- (void)ping;

- (void)cleanPushToken;
- (void)setVoIPPushToken:(NSData *)voIPPushToken;
- (void)sendPushAllowedIdentities;

- (void)setServerPorts: (NSArray *) ports;

- (void)sendPushOverrideTimeout;
- (void)resetPushOverrideTimeout;

- (void)completedProcessingAbstractMessage:(AbstractGroupMessage *)abstractGroupMsg;

@end
