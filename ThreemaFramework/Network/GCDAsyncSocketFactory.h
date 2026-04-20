#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

NS_ASSUME_NONNULL_BEGIN

@interface GCDAsyncSocketFactory : NSObject

+ (GCDAsyncSocket*)proxyAwareAsyncSocketForHost:(NSString*)host port:(NSNumber*)port delegate:(nullable id<GCDAsyncSocketDelegate>)delegate delegateQueue:(nullable dispatch_queue_t)delegateQueue;

@end

NS_ASSUME_NONNULL_END
