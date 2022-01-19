//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2022 Threema GmbH
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

#import "GroupPhotoSender.h"
#import "Conversation.h"
#import "Utils.h"
#import "NaClCrypto.h"
#import "MyIdentityStore.h"
#import "GroupSetPhotoMessage.h"
#import "MessageQueue.h"
#import "NSString+Hex.h"
#import "ActivityIndicatorProxy.h"
#import "SSLCAHelper.h"
#import "GroupSetPhotoMessage.h"
#import "GroupDeletePhotoMessage.h"
#import "Contact.h"
#import "BlobUtil.h"
#import "ThreemaError.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation GroupPhotoSender {
    Conversation *conversation;
    Contact *toMember;
    NSData *boxImageData;
    NSData *nonce;
    NSData *encryptionKey;
    NSMutableData *receivedData;
    NSURLConnection *uploadConnection;
    void(^onCompletion)(void);
    void(^onError)(NSError *error);
}

- (void)startWithImageData:(NSData *)imageData inConversation:(Conversation*)_conversation toMember:(Contact*)_toMember onCompletion:(void (^)(void))_onCompletion onError:(void (^)(NSError *))_onError {
    
    conversation = _conversation;
    toMember = _toMember;
    onCompletion = _onCompletion;
    onError = _onError;
    
    if (imageData != nil) { // New image
        /* Generate random symmetric key and encrypt */
        encryptionKey = [[NaClCrypto sharedCrypto] randomBytes:kBlobKeyLen];
        boxImageData = [[NaClCrypto sharedCrypto] symmetricEncryptData:imageData withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
        
        [self startUpload];
    } else { // Image was removed
        [self sendDeletePhotoMessage];
    }
}

- (void)startUpload {
    [ActivityIndicatorProxy startActivity];
    
    NSURL *blobUploadUrl = [BlobUtil urlForBlobUpload];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:blobUploadUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kBlobUploadTimeout];
    request.HTTPMethod = @"POST";
    
    NSString *boundary = @"---------------------------Boundary_Line";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSMutableData *body = [NSMutableData dataWithCapacity:boxImageData.length + 1024];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"blob\"; filename=\"blob.bin\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:boxImageData];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setHTTPBody:body];
    [request addValue:[NSString stringWithFormat:@"%lu", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
    
    receivedData = [NSMutableData data];
    
    uploadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [uploadConnection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [uploadConnection start];
}

- (void)uploadCompletedWithBlobId:(NSData*)blobId {
    
    if (toMember != nil) {
        /* send to the specified member only */
        [self sendSetPhotoMessageToMember:toMember withBlobId:blobId];
    } else {
        /* send to each group member */
        for (Contact *member in conversation.members) {
            [self sendSetPhotoMessageToMember:member withBlobId:blobId];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        onCompletion();
    });
}

- (void)sendDeletePhotoMessage {
    
    if (toMember != nil) {
        /* send to the specified member only */
        [self sendDeletePhotoMessageToMember:toMember];
    } else {
        /* send to each group member */
        for (Contact *member in conversation.members) {
            [self sendDeletePhotoMessageToMember:member];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        onCompletion();
    });
}

- (void)sendSetPhotoMessageToMember:(Contact*)member withBlobId:(NSData*)blobId {
    DDLogVerbose(@"Sending group photo message to %@", member.identity);
    GroupSetPhotoMessage *msg = [[GroupSetPhotoMessage alloc] init];
    msg.blobId = blobId;
    msg.size = (uint32_t)boxImageData.length;
    msg.encryptionKey = encryptionKey;
    msg.groupId = conversation.groupId;
    msg.groupCreator = [MyIdentityStore sharedMyIdentityStore].identity;
    msg.toIdentity = member.identity;
    [[MessageQueue sharedMessageQueue] enqueue:msg];
}

- (void)sendDeletePhotoMessageToMember:(Contact *)member {
    DDLogVerbose(@"Sending group delete photo message to %@", member.identity);
    GroupDeletePhotoMessage *msg = [[GroupDeletePhotoMessage alloc] init];
    msg.groupId = conversation.groupId;
    msg.groupCreator = [MyIdentityStore sharedMyIdentityStore].identity;
    msg.toIdentity = member.identity;
    [[MessageQueue sharedMessageQueue] enqueue:msg];
}

#pragma mark - URL connection delegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	DDLogVerbose(@"Request succeeded - received %lu bytes", (unsigned long)[receivedData length]);
    [ActivityIndicatorProxy stopActivity];
    
    NSString *blobIdHex = [[NSString alloc] initWithData:receivedData encoding:NSASCIIStringEncoding];
    NSData *blobId = [blobIdHex decodeHex];
    
    if (blobId.length != kBlobIdLen) {
        DDLogError(@"Got invalid blob ID from server: %@", blobId);
		[self connection:connection didFailWithError:[ThreemaError threemaError:@"Got invalid blob ID from server"]];
        return;
    }
    
    DDLogVerbose(@"Blob ID: %@", blobId);
	[self uploadCompletedWithBlobId:blobId];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {

	DDLogError(@"Connection failed - error %@ %@",
               [error localizedDescription],
               [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
	
    [ActivityIndicatorProxy stopActivity];
    
    onError(error);
}

/* this method ensures that HTTP errors get treated like connection failures etc. as well */
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[receivedData setLength:0];
	
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
	[receivedData appendData:data];
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
