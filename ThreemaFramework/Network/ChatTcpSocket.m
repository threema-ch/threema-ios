//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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
#import "ChatTcpSocket.h"
#import "GCDAsyncSocketFactory.h"
#import "SocketProtocolDelegate.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

static int currentPortIndex = 0;

@implementation ChatTcpSocket  {
    NSString *server;
    NSArray *ports;
    id<SocketProtocolDelegate> delegate;
    dispatch_queue_t queue;
    
    NSNumber *port;
    GCDAsyncSocket *socket;
}

- (nullable instancetype)initWithServer:(NSString * _Nonnull)server ports:(NSArray<NSNumber *> * _Nonnull)ports preferIPv6:(BOOL)preferIPv6 delegate:(id<SocketProtocolDelegate> _Nonnull)delegate queue:(dispatch_queue_t _Nullable)queue error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    
    self = [super init];
    if (self) {
        self->server = server;
        self->ports = ports;
        self->delegate = delegate;
        self->queue = queue;
        
        self->port = [self->ports objectAtIndex:currentPortIndex];
        
        socket = [GCDAsyncSocketFactory proxyAwareAsyncSocketForHost:server port:port delegate:self delegateQueue:queue];
        [socket setIPv4PreferredOverIPv6:!preferIPv6];

        _isProxyConnection = (socket != nil && ![socket isMemberOfClass:[GCDAsyncSocket class]]);
    }
    
    return self;
}

- (BOOL)isIPv6
{
    return [socket isIPv6];
}

- (BOOL)connect {
    DDLogInfo(@"Connecting to %@:%@...", server, port);
    
    NSError *error;
    if (![socket connectToHost:self->server onPort:[self->port intValue] withTimeout:kConnectTimeout error:&error]) {
        DDLogWarn(@"Connect failed: %@", error);
        return NO;
    }
    return YES;
}

- (void)disconnect {
    // Give the socket time for pending writes, but force disconnect if it takes too long for them to complete
    [socket disconnectAfterWriting];
    
    GCDAsyncSocket *socketToDisconnect = socket;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDisconnectTimeout * NSEC_PER_SEC)), queue, ^{
        if (socket == socketToDisconnect) {
            DDLogInfo(@"Socket still not disconnected - forcing disconnect now");
            [socket disconnect];
        }
    });
}

- (void)readWithLength:(uint32_t)length timeout:(int16_t)timeout tag:(int16_t)tag {
    [socket readDataToLength:length withTimeout:timeout tag:tag];
}


- (void)writeWithData:(NSData * _Nonnull)data tag:(int16_t)tag {
    [socket writeData:data withTimeout:kWriteTimeout tag:tag];
}

- (void)writeWithData:(NSData * _Nonnull)data {
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sender didConnectToHost:(NSString *)host port:(UInt16)port {
    if (sender != socket) {
        DDLogWarn(@"didConnectToHost from old socket");
        return;
    }
    
    DDLogInfo(@"Connected to %@:%d", host, port);
    [delegate didConnect];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sender withError:(NSError *)error {
    if (sender != socket) {
        DDLogWarn(@"Disconnect from chat server because of old socket");
        return;
    }

    NSInteger code = 0;
    if (error != nil) {
        DDLogError(@"Disconnect from chat server with error: %@", error);
        code = error.code;
        
        /* try next port */
        currentPortIndex++;
        if (currentPortIndex >= ports.count)
            currentPortIndex = 0;
    }

    socket = nil;

    DDLogInfo(@"Disconnected from %@:%d", [sender connectedHost], [sender connectedPort]);
    [delegate didDisconnectWithErrorCode:code];
}

- (void)socket:(GCDAsyncSocket *)sender didReadData:(NSData *)data withTag:(long)tag {
    if (sender != socket) {
        DDLogWarn(@"didReadData from old socket");
        return;
    }
    
    [delegate didReadData:data tag:(int)tag];
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sender shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    if (sender != socket) {
        DDLogWarn(@"shouldTimeoutReadWithTag from old socket");
        return 0;
    }
    
    DDLogInfo(@"Read timeout, tag = %ld", tag);
    [socket disconnect];
    return 0;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sender shouldTimeoutWriteWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    if (sender != socket) {
        DDLogWarn(@"shouldTimeoutWriteWithTag from old socket");
        return 0;
    }
    
    DDLogInfo(@"Write timeout, tag = %ld", tag);
    [socket disconnect];
    return 0;
}


@end
