//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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

#import "GCDAsyncSocketFactory.h"
#import "GCDAsyncSocket.h"
#import "GCDAsyncHTTPSProxySocket.h"
#import "GCDAsyncSOCKSProxySocket.h"
#import "ValidationLogger.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation GCDAsyncSocketFactory

static void _AutoConfigurationCallback(void *info, CFArrayRef proxyList, CFErrorRef error);

struct AutoConfigLoadStatus {
    bool finished;
    CFArrayRef proxyList;
};

+ (GCDAsyncSocket*)proxyAwareAsyncSocketForHost:(NSString*)host port:(NSNumber*)port delegate:(nullable id<GCDAsyncSocketDelegate>)delegate delegateQueue:(nullable dispatch_queue_t)delegateQueue { 
    NSDictionary *systemProxies = (__bridge NSDictionary*)CFNetworkCopySystemProxySettings();
    NSURL *targetUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@:%@", host, port]];
    NSArray *urlProxies = (__bridge NSArray*)CFNetworkCopyProxiesForURL((__bridge CFURLRef _Nonnull)targetUrl, (__bridge CFDictionaryRef _Nonnull)(systemProxies));
    
    return [GCDAsyncSocketFactory proxyAwareAsyncSocketForProxyList:urlProxies targetUrl:targetUrl delegate:delegate delegateQueue:delegateQueue];
}

+ (GCDAsyncSocket*)proxyAwareAsyncSocketForProxyList:(NSArray*)proxyList targetUrl:(NSURL*)targetUrl delegate:(nullable id<GCDAsyncSocketDelegate>)delegate delegateQueue:(nullable dispatch_queue_t)delegateQueue {
    if (proxyList.count > 0) {
        NSDictionary *proxy = proxyList[0];
        if ([proxy[(NSString*)kCFProxyTypeKey] isEqualToString:(NSString*)kCFProxyTypeSOCKS]) {
            NSString *host = proxy[(NSString*)kCFProxyHostNameKey];
            NSNumber *port = proxy[(NSString*)kCFProxyPortNumberKey];
            NSString *username = proxy[(NSString*)kCFProxyUsernameKey];
            NSString *password = proxy[(NSString*)kCFProxyPasswordKey];
            [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Using SOCKS proxy %@:%@", host, port]];
            GCDAsyncSOCKSProxySocket *proxySocket = [[GCDAsyncSOCKSProxySocket alloc] initWithDelegate:delegate delegateQueue:delegateQueue];
            [proxySocket setProxyHost:host port:port.intValue version:GCDAsyncSocketSOCKSVersion5];
            if (username && password) {
                [proxySocket setProxyUsername:username password:password];
            }
            return proxySocket;
        } else if ([proxy[(NSString*)kCFProxyTypeKey] isEqualToString:(NSString*)kCFProxyTypeHTTPS]) {
            NSString *host = proxy[(NSString*)kCFProxyHostNameKey];
            NSNumber *port = proxy[(NSString*)kCFProxyPortNumberKey];
            [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Using HTTPS proxy %@:%@", host, port]];
            GCDAsyncHTTPSProxySocket *proxySocket = [[GCDAsyncHTTPSProxySocket alloc] initWithDelegate:delegate delegateQueue:delegateQueue];
            [proxySocket setProxyHost:host port:port.intValue];
            return proxySocket;
        } else if ([proxy[(NSString*)kCFProxyTypeKey] isEqualToString:(NSString*)kCFProxyTypeAutoConfigurationURL]) {
            NSURL *autoConfigUrl = proxy[(NSString*)kCFProxyAutoConfigurationURLKey];
            [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Loading proxy auto config from %@", autoConfigUrl]];
            struct AutoConfigLoadStatus status;
            status.finished = false;
            CFStreamClientContext ctxt = { 0, &status, NULL, NULL, NULL };
            CFRunLoopSourceRef rls = CFNetworkExecuteProxyAutoConfigurationURL((__bridge CFURLRef _Nonnull)autoConfigUrl, (__bridge CFURLRef _Nonnull)(targetUrl), _AutoConfigurationCallback, &ctxt);
            CFStringRef mode = CFSTR("__GCDProxyAutoConfigRunLoopMode");
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, mode);
            CFAbsoluteTime stopTime = CFAbsoluteTimeGetCurrent() + 10.0;
            do {
                (void) CFRunLoopRunInMode(mode, 0.1, TRUE);
            } while (!status.finished && CFAbsoluteTimeGetCurrent() < stopTime);
            
            if (status.finished && status.proxyList) {
                DDLogVerbose(@"Auto config proxy list: %@", status.proxyList);
                return [GCDAsyncSocketFactory proxyAwareAsyncSocketForProxyList:(__bridge NSArray *)(status.proxyList) targetUrl:targetUrl delegate:delegate delegateQueue:delegateQueue];
            }
            
            if (rls) {
                if (CFRunLoopSourceIsValid(rls)) {
                    CFRunLoopSourceInvalidate(rls);
                    CFRelease(rls);
                }
            }
        }
    }
    
    return [[GCDAsyncSocket alloc] initWithDelegate:delegate delegateQueue:delegateQueue];
}

static void _AutoConfigurationCallback(void *info, CFArrayRef proxyList, CFErrorRef error) {
    struct AutoConfigLoadStatus *status = info;
    status->proxyList = proxyList;
    status->finished = true;
}

@end
