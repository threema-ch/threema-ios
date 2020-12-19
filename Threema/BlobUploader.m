//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "BlobUploader.h"
#import "ActivityIndicatorProxy.h"
#import "Contact.h"
#import "BlobUtil.h"
#import "BaseMessage.h"
#import "ThreemaError.h"
#import "SSLCAHelper.h"
#import "NSString+Hex.h"
#import "BlobUploadDelegate.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface BlobUploader ()

@property NSMutableData *receivedData;
@property NSURLConnection *uploadConnection;

@property id<BlobUploadDelegate> blobUploadDelegate;

@end

@implementation BlobUploader

- (void)startUploadFor:(id<BlobUploadDelegate>)messageProxy {
    _blobUploadDelegate = messageProxy;
    
    [ActivityIndicatorProxy startActivity];
    [_blobUploadDelegate uploadProgress: [NSNumber numberWithFloat:0]];
    
    NSURL *blobUploadUrl = [BlobUtil urlForBlobUpload];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:blobUploadUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kBlobUploadTimeout];
    request.HTTPMethod = @"POST";
    
    NSString *boundary = @"---------------------------Boundary_Line";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSUInteger dataLength = [self totalDataLength];
    NSMutableData *body = [NSMutableData dataWithCapacity: dataLength];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"blob\"; filename=\"blob.bin\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:_data];
    _data = nil;    // release memory now
    
    if (_thumbnailData) {
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];

        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"blob2\"; filename=\"blob2.bin\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:_thumbnailData];
        _thumbnailData = nil;    // release memory now
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    } else {
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [request setHTTPBody:body];
    [request addValue:[NSString stringWithFormat:@"%lu", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
    
    _receivedData = [NSMutableData data];
    
    _uploadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_uploadConnection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_uploadConnection start];
}

- (NSUInteger)totalDataLength {
    NSUInteger length = _data.length + 1024;
    if (_thumbnailData) {
        length += _thumbnailData.length;
    }
    
    return length;
}


#pragma mark - URL connection delegate

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    DDLogVerbose(@"totalBytesWritten: %ld, totalBytesExpectedToWrite: %ld", (long)totalBytesWritten, (long)totalBytesExpectedToWrite);
    
    if ([_blobUploadDelegate uploadShouldCancel]) {
        DDLogWarn(@"Upload cancelled");
        
        [connection cancel];
        
        [_blobUploadDelegate uploadDidCancel];
        return;
    }
    
    [_blobUploadDelegate uploadProgress: [NSNumber numberWithFloat:((float)totalBytesWritten / (float)totalBytesExpectedToWrite)]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    DDLogVerbose(@"Request succeeded - received %lu bytes", (unsigned long)[_receivedData length]);
    [ActivityIndicatorProxy stopActivity];
    
    NSString *blobIdHex = [[NSString alloc] initWithData:_receivedData encoding:NSASCIIStringEncoding];
    NSData *blobId = [blobIdHex decodeHex];
    
    if (blobId.length == kBlobIdLen) {
        DDLogVerbose(@"Blob ID: %@", blobId);
        [_blobUploadDelegate uploadSucceededWithBlobIds:@[blobId]];
    } else if (blobId.length == (2*kBlobIdLen)) {
        NSData *blobId1 = [NSData dataWithBytes:blobId.bytes length:kBlobIdLen];
        NSData *blobId2 = [NSData dataWithBytes:(blobId.bytes + kBlobIdLen) length:kBlobIdLen];
        
        DDLogVerbose(@"Blob ID: %@ / %@", blobId1, blobId2);
        [_blobUploadDelegate uploadSucceededWithBlobIds:@[blobId1, blobId2]];
    } else {
        DDLogError(@"Got invalid blob ID from server: %@", blobId);
        [self connection:connection didFailWithError:[ThreemaError threemaError:@"Got invalid blob ID from server"]];
    }
    
    _uploadConnection = nil;    // release memory for body etc. now
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    DDLogError(@"Connection failed - error %@ %@",
               [error localizedDescription],
               [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    
    [ActivityIndicatorProxy stopActivity];
    
    if ([_blobUploadDelegate uploadShouldCancel]) {
        DDLogWarn(@"Upload cancelled");
        
        [_blobUploadDelegate uploadDidCancel];
        return;
    }
    
    [_blobUploadDelegate uploadFailed];
    
    _uploadConnection = nil;    // release memory for body etc. now
}

/* this method ensures that HTTP errors get treated like connection failures etc. as well */
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [_receivedData setLength:0];
    
    NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];
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
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [SSLCAHelper connection:connection canAuthenticateAgainstProtectionSpace:protectionSpace];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [SSLCAHelper connection:connection didReceiveAuthenticationChallenge:challenge];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

@end
