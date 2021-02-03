//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2021 Threema GmbH
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

#import "HTTPSURLLoader.h"
#import "ThreemaError.h"
#import "BlobUtil.h"
#import "ActivityIndicatorProxy.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface HTTPSURLLoader ()

@property NSMutableData *receivedData;
@property NSURLConnection *downloadConnection;
@property (copy) void(^onCompletion)(NSData *data);
@property (copy) void(^onError)(NSError *error);

@end

@implementation HTTPSURLLoader

- (void)startWithURLRequest:(NSURLRequest*)urlRequest onCompletion:(void (^)(NSData *))onCompletion onError:(void (^)(NSError *))onError {
    DDLogVerbose(@"Requesting: %@", urlRequest.URL);

    _onCompletion = onCompletion;
    _onError = onError;
    
    _receivedData = [NSMutableData data];
    _downloadConnection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self];

    [ActivityIndicatorProxy startActivity];
}

- (void)startWithBlobId:(NSData*)blobId onCompletion:(void (^)(NSData *))onCompletion onError:(void (^)(NSError *))onError {

    NSURL *blobUrl = [BlobUtil urlForBlobId:blobId];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:blobUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kBlobLoadTimeout];

    [self startWithURLRequest:request onCompletion:onCompletion onError:onError];
}

#pragma mark - URL connection delegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	DDLogVerbose(@"Request succeeded - received %lu bytes", (unsigned long)[_receivedData length]);
    
    [ActivityIndicatorProxy stopActivity];
    _onCompletion(_receivedData);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	DDLogError(@"Connection failed - error %@ %@",
               [error localizedDescription],
               [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    
    [ActivityIndicatorProxy stopActivity];
    _onError(error);
}

/* this method ensures that HTTP errors get treated like connection failures etc. as well */
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[_receivedData setLength:0];
	
    NSHTTPURLResponse *httpURLResponse = ((NSHTTPURLResponse *)response);
    _responseHeaderFields = httpURLResponse.allHeaderFields;
    
	NSInteger statusCode = [httpURLResponse statusCode];
	if (statusCode >= 400)
	{
		[connection cancel];  // stop connecting; no more delegate messages
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:
                                                                      NSLocalizedString(@"Server returned status code %d",@""),
                                                                      statusCode]
                                                              forKey:NSLocalizedDescriptionKey];
		NSError *statusError = [NSError errorWithDomain:NSURLErrorDomain
                                                   code:statusCode
                                               userInfo:errorInfo];
		[self connection:connection didFailWithError:statusError];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[_receivedData appendData:data];

    if ([_delegate respondsToSelector:@selector(httpsLoaderShouldCancel)]) {
        if ([_delegate httpsLoaderShouldCancel]) {
            DDLogInfo(@"dowload cancelled");
            
            [connection cancel];
            
            [ActivityIndicatorProxy stopActivity];
            _onError([ThreemaError threemaError:@"User cancelled download" withCode:kErrorCodeUserCancelled]);
            
            return;
        }
    }

    if ([_delegate respondsToSelector:@selector(httpsLoaderReceivedData:)]) {
        [_delegate httpsLoaderReceivedData:_receivedData];
    }
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
