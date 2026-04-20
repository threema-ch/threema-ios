#import <Foundation/Foundation.h>
#import "BlobOrigin.h"

@interface HTTPSURLLoader : NSObject <NSURLConnectionDataDelegate>

@property NSDictionary *responseHeaderFields;

- (void)startWithBlobId:(NSData*)blobId origin:(BlobOrigin)origin onCompletion:(void (^)(NSData *))onCompletion onError:(void (^)(NSError *))onError;

- (void)startWithURLRequest:(NSURLRequest*)urlRequest onCompletion:(void (^)(NSData *data))onCompletion onError:(void (^)(NSError *error))onError;

@end
