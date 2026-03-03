//
//  GCDAsyncSOCKSProxySocket.h
//
//  Copyright © 2019 Threema GmbH. All rights reserved.
//  Derived from ProxyKit, Copyright (c) 2014 Chris Ballinger
//

#include "GCDAsyncSocket.h"

typedef NS_ENUM(int16_t, GCDAsyncSocketSOCKSVersion) {
    GCDAsyncSocketSOCKSVersion4 = 0,    // Not implemented
    GCDAsyncSocketSOCKSVersion4a,       // Not implemented
    GCDAsyncSocketSOCKSVersion5         // WIP
};

@interface GCDAsyncSOCKSProxySocket : GCDAsyncSocket <GCDAsyncSocketDelegate>

// SOCKS proxy settings
@property (nonatomic, strong, readonly) NSString *proxyHost;
@property (nonatomic, readonly) uint16_t proxyPort;
@property (nonatomic, readonly) GCDAsyncSocketSOCKSVersion proxyVersion;

@property (nonatomic, strong, readonly) NSString *proxyUsername;
@property (nonatomic, strong, readonly) NSString *proxyPassword;

/**
 * SOCKS Proxy settings
 **/
- (void) setProxyHost:(NSString*)host port:(uint16_t)port version:(GCDAsyncSocketSOCKSVersion)version;
- (void) setProxyUsername:(NSString *)username password:(NSString*)password;

@end
