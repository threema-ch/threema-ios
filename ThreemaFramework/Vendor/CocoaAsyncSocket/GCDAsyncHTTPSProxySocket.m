//
//  GCDAsyncHTTPSProxySocket.m
//
//  Copyright © 2019 Threema GmbH. All rights reserved.
//  Derived from ProxyKit, Copyright (c) 2014 Chris Ballinger
//

#import "GCDAsyncHTTPSProxySocket.h"

#if DEBUG
    static const int ddLogLevel = DDLogLevelVerbose;
#else
    static const int ddLogLevel = DDLogLevelOff;
#endif


// Define various socket tags
#define HTTP_CONNECT         10100

// Timeouts
#define TIMEOUT_CONNECT       8.00
#define TIMEOUT_READ          5.00
#define TIMEOUT_TOTAL        80.00

@interface GCDAsyncHTTPSProxySocket()
@property (nonatomic, strong, readonly) GCDAsyncSocket *proxySocket;
@property (nonatomic, readonly) dispatch_queue_t proxyDelegateQueue;
@property (nonatomic, strong, readonly) NSString *destinationHost;
@property (nonatomic, readonly) uint16_t destinationPort;
@property (nonatomic, strong) NSError *lastDisconnectError;
@end

@implementation GCDAsyncHTTPSProxySocket

- (void) setProxyHost:(NSString *)host port:(uint16_t)port {
    _proxyHost = host;
    _proxyPort = port;
}

#pragma mark Overridden methods

- (id)initWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq socketQueue:(dispatch_queue_t)sq {
    if (self = [super initWithDelegate:aDelegate delegateQueue:dq socketQueue:sq]) {
        _proxyHost = nil;
        _proxyPort = 0;
        _destinationHost = nil;
        _destinationPort = 0;
        _proxyDelegateQueue = dispatch_queue_create("GCDAsyncHTTPSProxySocket delegate queue", 0);
        
    }
    return self;
}

- (BOOL)connectToHost:(NSString *)inHost
               onPort:(uint16_t)port
         viaInterface:(NSString *)inInterface
          withTimeout:(NSTimeInterval)timeout
                error:(NSError **)errPtr
{
    if (!self.proxySocket) {
        _proxySocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.proxyDelegateQueue socketQueue:NULL];
    }
    _destinationHost = inHost;
    _destinationPort = port;
    return [self.proxySocket connectToHost:self.proxyHost onPort:self.proxyPort viaInterface:inInterface withTimeout:timeout error:errPtr];
}

/** Returns YES if tag is reserved for internal functions */
- (BOOL) checkForReservedTag:(long)tag {
    if (tag == HTTP_CONNECT) {
        return YES;
    } else {
        return NO;
    }
}

- (void) writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag {
    if ([self checkForReservedTag:tag]) {
        DDLogError(@"This tag is reserved and won't work: %ld", tag);
        return;
    }
    [self.proxySocket writeData:data withTimeout:timeout tag:tag];
}

- (void)readDataWithTimeout:(NSTimeInterval)timeout buffer:(NSMutableData *)buffer bufferOffset:(NSUInteger)offset tag:(long)tag {
    if ([self checkForReservedTag:tag]) {
        DDLogError(@"This tag is reserved and won't work: %ld", tag);
        return;
    }
    [self.proxySocket readDataWithTimeout:timeout buffer:buffer bufferOffset:offset tag:tag];
}
- (void)readDataWithTimeout:(NSTimeInterval)timeout buffer:(NSMutableData *)buffer bufferOffset:(NSUInteger)offset maxLength:(NSUInteger)length tag:(long)tag {
    if ([self checkForReservedTag:tag]) {
        DDLogError(@"This tag is reserved and won't work: %ld", tag);
        return;
    }
    [self.proxySocket readDataWithTimeout:timeout buffer:buffer bufferOffset:offset maxLength:length tag:tag];
}
- (void) readDataWithTimeout:(NSTimeInterval)timeout tag:(long)tag {
    if ([self checkForReservedTag:tag]) {
        DDLogError(@"This tag is reserved and won't work: %ld", tag);
        return;
    }
    [self.proxySocket readDataWithTimeout:timeout tag:tag];
}
- (void)readDataToLength:(NSUInteger)length withTimeout:(NSTimeInterval)timeout tag:(long)tag {
    if ([self checkForReservedTag:tag]) {
        DDLogError(@"This tag is reserved and won't work: %ld", tag);
        return;
    }
    [self.proxySocket readDataToLength:length withTimeout:timeout tag:tag];
}
- (void)readDataToLength:(NSUInteger)length withTimeout:(NSTimeInterval)timeout buffer:(NSMutableData *)buffer bufferOffset:(NSUInteger)offset tag:(long)tag {
    if ([self checkForReservedTag:tag]) {
        DDLogError(@"This tag is reserved and won't work: %ld", tag);
        return;
    }
    [self.proxySocket readDataToLength:length withTimeout:timeout buffer:buffer bufferOffset:offset tag:tag];
}
- (void)readDataToData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag {
    if ([self checkForReservedTag:tag]) {
        DDLogError(@"This tag is reserved and won't work: %ld", tag);
        return;
    }
    [self.proxySocket readDataToData:data withTimeout:timeout tag:tag];
}
- (void)readDataToData:(NSData *)data withTimeout:(NSTimeInterval)timeout buffer:(NSMutableData *)buffer bufferOffset:(NSUInteger)offset tag:(long)tag {
    if ([self checkForReservedTag:tag]) {
        DDLogError(@"This tag is reserved and won't work: %ld", tag);
        return;
    }
    [self.proxySocket readDataToData:data withTimeout:timeout buffer:buffer bufferOffset:offset tag:tag];
}
- (void)readDataToData:(NSData *)data withTimeout:(NSTimeInterval)timeout maxLength:(NSUInteger)length tag:(long)tag {
    if ([self checkForReservedTag:tag]) {
        DDLogError(@"This tag is reserved and won't work: %ld", tag);
        return;
    }
    [self.proxySocket readDataToData:data withTimeout:timeout maxLength:length tag:tag];
}
- (void)readDataToData:(NSData *)data withTimeout:(NSTimeInterval)timeout buffer:(NSMutableData *)buffer bufferOffset:(NSUInteger)offset maxLength:(NSUInteger)length tag:(long)tag {
    if ([self checkForReservedTag:tag]) {
        DDLogError(@"This tag is reserved and won't work: %ld", tag);
        return;
    }
    [self.proxySocket readDataToData:data withTimeout:timeout buffer:buffer bufferOffset:offset maxLength:length tag:tag];
}

- (void) startTLS:(NSDictionary *)tlsSettings {
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:tlsSettings];
    /*
    NSString *peerName = self.destinationHost;
    [settings setObject:peerName forKey:(NSString *)kCFStreamSSLPeerName];
    */
    [self.proxySocket startTLS:settings];
}

- (void) disconnect {
    self.lastDisconnectError = nil;
    [self.proxySocket disconnect];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark HTTP
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Sends the HTTP CONNECT request, and starts reading the response.
 **/
- (void)httpConnect
{
    NSString *connectRequest = [NSString stringWithFormat:@"CONNECT %@:%d HTTP/1.1\r\nHost: %@:%d\r\nUser-Agent: Threema\r\nConnection: keep-alive\r\nProxy-Connection: keep-alive\r\n\r\n",
                                self.destinationHost, self.destinationPort, self.destinationHost, self.destinationPort];
    [self.proxySocket writeData:[connectRequest dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:HTTP_CONNECT];
	
    [self.proxySocket readDataToData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:TIMEOUT_READ tag:HTTP_CONNECT];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    DDLogInfo(@"proxySocket did connect to %@:%d", host, port);
	
	[self httpConnect];
}

- (void) socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    DDLogVerbose(@"read partial data with tag %ld of length %d", tag, (int)partialLength);
    if (self.delegate && [self.delegate respondsToSelector:@selector(socket:didReadPartialDataOfLength:tag:)]) {
        dispatch_async(self.delegateQueue, ^{
            @autoreleasepool {
                [self.delegate socket:self didReadPartialDataOfLength:partialLength tag:tag];
            }
        });
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    DDLogVerbose(@"did read tag[%ld] data: %@", tag, data);
	
	if (tag == HTTP_CONNECT)
	{
        NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        DDLogVerbose(@"GCDAsyncHTTPSProxySocket: HTTP_CONNECT response: %@", response);
        
        NSInteger statusCode = -1;
        NSRegularExpression *responseRegex = [NSRegularExpression regularExpressionWithPattern:@"^HTTP\\S+ (\\d+) " options:0 error:nil];
        NSTextCheckingResult *result = [responseRegex firstMatchInString:response options:0 range:NSMakeRange(0, response.length)];
        if (result.numberOfRanges == 2) {
            statusCode = [[response substringWithRange:[result rangeAtIndex:1]] integerValue];
        }
        
        if (statusCode != 200) {
            DDLogError(@"Proxy returned status code %ld", (long)statusCode);
            self.lastDisconnectError = [NSError errorWithDomain:NSURLErrorDomain code:statusCode userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Proxy server returned status code %ld", (long)statusCode]}];
            [self.proxySocket disconnect];
            return;
        }
		
        if (self.delegate && [self.delegate respondsToSelector:@selector(socket:didConnectToHost:port:)]) {
            dispatch_async(self.delegateQueue, ^{
                @autoreleasepool {
                    [self.delegate socket:self didConnectToHost:self.destinationHost port:self.destinationPort];
                }
            });
        }
	}
    else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(socket:didReadData:withTag:)]) {
            dispatch_async(self.delegateQueue, ^{
                @autoreleasepool {
                    [self.delegate socket:self didReadData:data withTag:tag];
                }
            });
        }
    }
}


#pragma mark GCDAsyncSocketDelegate methods


- (void) socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    if (self.delegate && [self.delegate respondsToSelector:@selector(socket:didWriteDataWithTag:)]) {
        dispatch_async(self.delegateQueue, ^{
            @autoreleasepool {
                [self.delegate socket:self didWriteDataWithTag:tag];
            }
        });
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    DDLogVerbose(@"proxySocket disconnected from proxy %@:%d / destination %@:%d", self.proxyHost, self.proxyPort, self.destinationHost, self.self.destinationPort);

    if (self.delegate && [self.delegate respondsToSelector:@selector(socketDidDisconnect:withError:)]) {
        dispatch_async(self.delegateQueue, ^{
            @autoreleasepool {
                [self.delegate socketDidDisconnect:self withError:(err != nil ? err : self.lastDisconnectError)];
            }
        });
    }
}

- (void) socketDidSecure:(GCDAsyncSocket *)sock {
    DDLogVerbose(@"didSecure proxy %@:%d / destination %@:%d", self.proxyHost, self.proxyPort, self.destinationHost, self.self.destinationPort);
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(socketDidSecure:)]) {
        dispatch_async(self.delegateQueue, ^{
            @autoreleasepool {
                [self.delegate socketDidSecure:self];
            }
        });
    }
}

- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(socketDidCloseReadStream:)]) {
        dispatch_async(self.delegateQueue, ^{
            @autoreleasepool {
                [self.delegate socketDidCloseReadStream:self];
            }
        });
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(socket:didWritePartialDataOfLength:tag:)]) {
        dispatch_async(self.delegateQueue, ^{
            @autoreleasepool {
                [self.delegate socket:self didWritePartialDataOfLength:partialLength tag:tag];
            }
        });
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL))completionHandler
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(socket:didReceiveTrust:completionHandler:)]) {
        dispatch_async(self.delegateQueue, ^{
            @autoreleasepool {
                [self.delegate socket:self didReceiveTrust:trust completionHandler:completionHandler];
            }
        });
    }
}


@end
