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

#import "ServerAPIRequest.h"
#import "ActivityIndicatorProxy.h"
#import "SSLCAHelper.h"
#import "UserSettings.h"
#import "ThreemaError.h"
#import "BundleUtil.h"
#import "LicenseStore.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
#define REQUEST_TIMEOUT 30.0

@implementation ServerAPIRequest

@synthesize onCompletion, onError;

+ (void)loadJSONFromAPIPath:(NSString*)apiPath withCachePolicy:(NSURLRequestCachePolicy)cachePolicy onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError {
    [ServerAPIRequest loadJSONFromAPIPath:apiPath apiUrl:[ServerAPIRequest apiUrl] getParams:nil withCachePolicy:cachePolicy onCompletion:onCompletion onError:onError];
}

+ (void)loadJSONFromWorkAPIPath:(NSString*)apiPath getParams:(NSString*)getParams withCachePolicy:(NSURLRequestCachePolicy)cachePolicy onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError {
    [ServerAPIRequest loadJSONFromAPIPath:apiPath apiUrl:[ServerAPIRequest workApiUrl] getParams:getParams withCachePolicy:cachePolicy onCompletion:onCompletion onError:onError];
}

+ (void)loadJSONFromAPIPath:(NSString*)apiPath apiUrl:(NSURL*)apiUrl getParams:(NSString*)getParams withCachePolicy:(NSURLRequestCachePolicy)cachePolicy onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError {
	ServerAPIRequest *loader = [[ServerAPIRequest alloc] init];
	
	loader.onCompletion = onCompletion;
	loader.onError = onError;
    
    NSURL *url = [apiUrl URLByAppendingPathComponent:apiPath];
    if (getParams != nil) {
        url = [NSURL URLWithString:getParams relativeToURL:url];
    }
	
    [ActivityIndicatorProxy startActivity];
    
	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:cachePolicy timeoutInterval:REQUEST_TIMEOUT];
    NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
    conf.requestCachePolicy = cachePolicy;
    if (cachePolicy == NSURLRequestReloadIgnoringLocalCacheData || cachePolicy == NSURLRequestReloadIgnoringLocalAndRemoteCacheData) {
        conf.URLCache = nil;
    }
    NSURLSession *session = [NSURLSession sessionWithConfiguration:conf delegate:loader delegateQueue:[NSOperationQueue currentQueue]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self connectionCompletionHandler:data response:response error:error onCompletion:onCompletion onError:onError];
    }];
    [task resume];
    [session finishTasksAndInvalidate];
}

+ (void)postJSONToAPIPath:(NSString*)apiPath data:(id)jsonObject onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError {
    [ServerAPIRequest postJSONToAPIPath:apiPath apiUrl:[ServerAPIRequest apiUrl] data:jsonObject onCompletion:onCompletion onError:onError];
}

+ (void)postJSONToWorkAPIPath:(NSString*)apiPath data:(id)jsonObject onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError {
    [ServerAPIRequest postJSONToAPIPath:apiPath apiUrl:[ServerAPIRequest workApiUrl] data:jsonObject onCompletion:onCompletion onError:onError];
}

+ (void)postJSONToAPIPath:(NSString*)apiPath apiUrl:(NSURL*)apiUrl data:(id)jsonObject onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError {
	
	ServerAPIRequest *loader = [[ServerAPIRequest alloc] init];
	
	loader.onCompletion = onCompletion;
	loader.onError = onError;
	
    NSURL *url = [apiUrl URLByAppendingPathComponent:apiPath];
    
    NSError *jsonError;
    NSData *jsonRequest = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:&jsonError];
    if (jsonRequest == nil) {
        DDLogError(@"Could not generate JSON data: %@", jsonError);
        onError(jsonError);
        return;
    }
    
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
										 timeoutInterval:REQUEST_TIMEOUT];
	
	[request setHTTPMethod:@"POST"];
    [request addValue:[NSLocale currentLocale].languageCode forHTTPHeaderField:@"Accept-Language"];    
    
	[request setHTTPBody:jsonRequest];
	
    DDLogVerbose(@"post JSON to %@: %@", url, jsonObject);
    
    [ActivityIndicatorProxy startActivity];
    
    NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
    conf.requestCachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    conf.URLCache = nil;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:conf delegate:loader delegateQueue:[NSOperationQueue currentQueue]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self connectionCompletionHandler:data response:response error:error onCompletion:onCompletion onError:onError];
    }];
    [task resume];
    [session finishTasksAndInvalidate];
}

+ (void)connectionCompletionHandler:(NSData* _Nullable)data response:(NSURLResponse* _Nullable)response error:(NSError* _Nullable)error onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError {
    
    DDLogVerbose(@"JSON load succeeded - received %lu bytes", (unsigned long)[data length]);
    
    [ActivityIndicatorProxy stopActivity];
    
    // Check for client-side error (e.g. no connection to server)
    if (error != nil) {
        onError(error);
        return;
    }
    
    // Check for erroneous HTTP status code (NSURLSession does not report server-side errors in error object!)
    if (((NSHTTPURLResponse*)response).statusCode >= 400) {
        NSError *httpError = [NSError errorWithDomain:NSURLErrorDomain code:((NSHTTPURLResponse*)response).statusCode userInfo:nil];
        onError(httpError);
        return;
    }
    
    id jsonResult = nil;
    NSError *jsonError;

    if (data != nil) {
        jsonResult = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    }
    
    if (jsonResult == nil) {
        DDLogError(@"Could not parse JSON data: %@", jsonError);
        onError(jsonError);
        return;
    }
    
    /* Check for "error" key in dictionary - if so, don't call onCompletion */
    if ([jsonResult isKindOfClass:[NSDictionary class]]) {
        NSDictionary *jsonDict = (NSDictionary*)jsonResult;
        NSString *errorStr = [jsonDict objectForKey:@"error"];
        if (errorStr != nil) {
            onError([ThreemaError threemaError:errorStr]);
            return;
        }
    }

    onCompletion(jsonResult);
}

+ (NSURL*)apiUrl {
    if ([LicenseStore requiresLicenseKey]) {
        if ([UserSettings sharedUserSettings].enableIPv6)
            return [NSURL URLWithString:[BundleUtil objectForInfoDictionaryKey:@"ThreemaAPIURLv6Work"]];
        else
            return [NSURL URLWithString:[BundleUtil objectForInfoDictionaryKey:@"ThreemaAPIURLWork"]];
    } else {
        if ([UserSettings sharedUserSettings].enableIPv6)
            return [NSURL URLWithString:[BundleUtil objectForInfoDictionaryKey:@"ThreemaAPIURLv6"]];
        else
            return [NSURL URLWithString:[BundleUtil objectForInfoDictionaryKey:@"ThreemaAPIURL"]];
    }
    
}

+ (NSURL*)workApiUrl {
    if ([UserSettings sharedUserSettings].enableIPv6) {
        return [NSURL URLWithString:[BundleUtil objectForInfoDictionaryKey:@"ThreemaWorkAPIURLv6"]];
    } else {
        return [NSURL URLWithString:[BundleUtil objectForInfoDictionaryKey:@"ThreemaWorkAPIURL"]];
    }
}

- (id)init
{
    self = [super init];
    return self;
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error
{
    if (error != nil) {
        DDLogError(@"Connection failed - error %@ %@",
                   [error localizedDescription],
                   [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
        
        [ActivityIndicatorProxy stopActivity];
        
        if (onError != nil)
            onError(error);
    }
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
{
    [SSLCAHelper session:session didReceiveAuthenticationChallenge:challenge completion:completionHandler];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    switch (connection.currentRequest.cachePolicy) {
        case NSURLRequestReloadIgnoringLocalCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            return cachedResponse;
    }
}

@end
