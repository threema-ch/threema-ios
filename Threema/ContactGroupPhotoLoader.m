//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2020 Threema GmbH
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

#import "ContactGroupPhotoLoader.h"
#import "ActivityIndicatorProxy.h"
#import "NSString+Hex.h"
#import "ProtocolDefines.h"
#import "Utils.h"
#import "NaClCrypto.h"
#import "SSLCAHelper.h"
#import "EntityManager.h"
#import "BlobUtil.h"
#import "ThreemaError.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation ContactGroupPhotoLoader {
    NSData *blobId;
    NSData *encryptionKey;
    NSMutableData *receivedData;
    NSURLSessionDataTask *downloadConnection;
    void(^onCompletion)(NSData *imageData);
    void(^onError)(NSError *error);
}

- (void)startWithBlobId:(NSData*)_blobId encryptionKey:(NSData*)_encryptionKey onCompletion:(void (^)(NSData *))_onCompletion onError:(void (^)(NSError *))_onError {
    
    onCompletion = _onCompletion;
    onError = _onError;
    blobId = _blobId;
    encryptionKey = _encryptionKey;
    
    /* Fetch image data */
    NSURL *imageBlobUrl = [BlobUtil urlForBlobId:blobId];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:imageBlobUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kBlobLoadTimeout];
    
    receivedData = [NSMutableData data];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    downloadConnection = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [receivedData setLength:0];
        
        NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];
        if (statusCode >= 400)
        {
            [session invalidateAndCancel];  // stop connecting; no more delegate messages
            NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:
                                                                          NSLocalizedString(@"Server returned status code %d",@""),
                                                                          statusCode]
                                                                  forKey:NSLocalizedDescriptionKey];
            NSError *statusError = [NSError errorWithDomain:NSURLErrorDomain code:statusCode userInfo:errorInfo];
            DDLogError(@"Connection failed - error %@ %@",
                       [statusError localizedDescription],
                       [[statusError userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
            
            onError([ThreemaError threemaError:[error localizedDescription] withCode:statusError.code]);
            
            [ActivityIndicatorProxy stopActivity];
        }
        else if (error) {
            DDLogError(@"Connection failed - error %@ %@",
                       [error localizedDescription],
                       [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
            
            onError([ThreemaError threemaError:[error localizedDescription] withCode:error.code]);
            
            [ActivityIndicatorProxy stopActivity];
        } else {
            [receivedData appendData:data];
            DDLogVerbose(@"Request succeeded - received %lu bytes", (unsigned long)[receivedData length]);
            [ActivityIndicatorProxy stopActivity];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self downloadCompleted];
            });
        }
    }];
    [downloadConnection resume];
}

- (void)downloadCompleted {
    
    /* Decrypt the box */
    NSData *imageData = [[NaClCrypto sharedCrypto] symmetricDecryptData:receivedData withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
    
    if (imageData == nil) {
        onError([ThreemaError threemaError:@"Image blob decryption failed"]);
        return;
    }
    
    onCompletion(imageData);
}
 
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(nonnull NSURLAuthenticationChallenge *)challenge completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    [SSLCAHelper session:session didReceiveAuthenticationChallenge:challenge completion:completionHandler];
}

- (void)URLSession:(NSURLSession *)session dataTask:(nonnull NSURLSessionDataTask *)dataTask willCacheResponse:(nonnull NSCachedURLResponse *)proposedResponse completionHandler:(nonnull void (^)(NSCachedURLResponse * _Nullable))completionHandler {
    completionHandler(nil);
}

@end
