//
//  GCDAsyncHTTPSProxySocket.h
//
//  Copyright © 2019 Threema GmbH. All rights reserved.
//  Derived from ProxyKit, Copyright (c) 2014 Chris Ballinger
//

#include "GCDAsyncSocket.h"

typedef NS_ENUM(int16_t, GCDAsyncProxySocketError) {
	GCDAsyncProxySocketNoError = 0,           // Never used
    GCDAsyncProxySocketAuthenticationError
};

@interface GCDAsyncHTTPSProxySocket : GCDAsyncSocket <GCDAsyncSocketDelegate>

// HTTPS proxy settings
@property (nonatomic, strong, readonly) NSString *proxyHost;
@property (nonatomic, readonly) uint16_t proxyPort;

- (void) setProxyHost:(NSString*)host port:(uint16_t)port;

@end
