#import <Foundation/Foundation.h>

typedef void(^CompletionCallback)(id jsonObject);
typedef void(^ErrorCallback)(NSError *error);

@interface ServerAPIRequest : NSObject <NSURLSessionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) CompletionCallback onCompletion;
@property (nonatomic, strong) ErrorCallback onError;

+ (void)loadJSONFromAPIPath:(NSString*)apiPath withCachePolicy:(NSURLRequestCachePolicy)cachePolicy onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError;

+ (void)postJSONToAPIPath:(NSString*)apiPath data:(id)jsonObject onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError;

+ (void)loadJSONFromWorkAPIPath:(NSString*)apiPath getParams:(NSString*)getParams withCachePolicy:(NSURLRequestCachePolicy)cachePolicy onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError;

+ (void)postJSONToWorkAPIPath:(NSString*)apiPath data:(id)jsonObject onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError;

@end
