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

#import "ContactPhotoSender.h"
#import "Conversation.h"
#import "Utils.h"
#import "NaClCrypto.h"
#import "MyIdentityStore.h"
#import "ContactSetPhotoMessage.h"
#import "ContactDeletePhotoMessage.h"
#import "ContactRequestPhotoMessage.h"
#import "MessageQueue.h"
#import "NSString+Hex.h"
#import "ActivityIndicatorProxy.h"
#import "SSLCAHelper.h"
#import "Contact.h"
#import "BlobUtil.h"
#import "ThreemaError.h"
#import "ContactStore.h"
#import "EntityManager.h"
#import "UserSettings.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

#define kTimeToUploadNextBlob -60*60*24*7

@implementation ContactPhotoSender {
    Contact *toMember;
    NSData *boxImageData;
    NSData *nonce;
    NSData *encryptionKey;
    NSMutableData *receivedData;
    NSURLConnection *uploadConnection;
    void(^onCompletion)(void);
    void(^onError)(NSError *error);
}

// MARK: - Profile picture request send

+ (void)sendProfilePictureRequest:(NSString *)toIdentity {
    DDLogVerbose(@"send profile pic request to %@", toIdentity);
    ContactRequestPhotoMessage *msg = [[ContactRequestPhotoMessage alloc] init];
    msg.toIdentity = toIdentity;
    [[MessageQueue sharedMessageQueue] enqueue:msg];
}

// MARK: - Profile picture send/upload

+ (Contact *)shouldSendProfilePictureToContact:(NSString *)identity {
    enum SendProfilePicture preference = [UserSettings sharedUserSettings].sendProfilePicture;
    
    if (preference == SendProfilePictureNone) {
        return nil;
    }
    else if (preference == SendProfilePictureContacts) {
        NSArray *contactIdentities = [UserSettings sharedUserSettings].profilePictureContactList;
        NSSet *selectedContacts = [NSMutableSet setWithArray:contactIdentities];
        if (![selectedContacts containsObject:identity]) {
            return nil;
        }
    }
    
    Contact *contact = [[ContactStore sharedContactStore] contactForIdentity:identity];
    
    if (contact.isGatewayId || contact.isEchoEcho) {
        return nil;
    }
    
    if (!contact.isProfilePictureSended) {
        return contact;
    }
    return nil;
}

+ (void)sendProfilePicture:(AbstractMessage *)message {
    if ([message allowToSendProfilePicture]) {
        Contact *contact = [ContactPhotoSender shouldSendProfilePictureToContact:message.toIdentity];
        if (contact) {
            // send profile picture
            ContactPhotoSender *sender = [[ContactPhotoSender alloc] init];
            [sender startWithImageToMember:contact onCompletion:^{
            } onError:^(NSError *err) {
            }];
        }

        ContactStore *contactStore = [ContactStore sharedContactStore];
        if ([contactStore existsProfilePictureRequest:message.toIdentity]) {
            // send profile picture request
            [ContactPhotoSender sendProfilePictureRequest:message.toIdentity];

            [contactStore removeProfilePictureRequest:message.toIdentity];
        }
    }
}

- (void)startWithImageToMember:(Contact*)_toMember onCompletion:(void (^)(void))_onCompletion onError:(void (^)(NSError *))_onError {
    
    toMember = _toMember;
    onCompletion = _onCompletion;
    onError = _onError;
    
    NSMutableDictionary *profilePicture = [[MyIdentityStore sharedMyIdentityStore] profilePicture];
    if (profilePicture[@"ProfilePicture"] == nil) {
        if (toMember != nil) {
            // save to database
            EntityManager *entityManager = [[EntityManager alloc] init];
            [entityManager performAsyncBlockAndSafe:^{
                toMember.profilePictureSended = YES;
                toMember.profilePictureUpload = [NSDate date];
            }];
            /* send to the specified member only */
            [self sendDeletePhotoMessageToMember:toMember];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            onCompletion();
        });
    } else {
        // check if date is older then 2 weeks when uploading blob, when not send only the blob id in the message
        NSMutableDictionary *profilePicture = [[MyIdentityStore sharedMyIdentityStore] profilePicture];
        NSDate *lastUpload = profilePicture[@"LastUpload"];
        NSDate *blobValidDate = [NSDate dateWithTimeIntervalSinceNow:kTimeToUploadNextBlob];
        if (lastUpload && [lastUpload earlierDate:blobValidDate] == blobValidDate) {
            if (toMember != nil) {
                // save to database
                EntityManager *entityManager = [[EntityManager alloc] init];
                [entityManager performAsyncBlockAndSafe:^{
                    toMember.profilePictureSended = YES;
                    toMember.profilePictureUpload = [NSDate date];
                }];
                /* send to the specified member only */
                [self sendSetPhotoMessageToMember:toMember withProfilePicture:profilePicture];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                onCompletion();
            });
        } else {
            /* Generate random symmetric key and encrypt */
            encryptionKey = [[NaClCrypto sharedCrypto] randomBytes:kBlobKeyLen];
            boxImageData = [[NaClCrypto sharedCrypto] symmetricEncryptData:profilePicture[@"ProfilePicture"] withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
            
            [self startUpload];
        }
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
    
    uploadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)uploadCompletedWithBlobId:(NSData*)blobId {
    
    if (toMember != nil) {
        /* send to the specified member only */
        [self sendSetPhotoMessageToMember:toMember withBlobId:blobId];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        onCompletion();
    });
}

- (void)sendSetPhotoMessageToMember:(Contact*)member withBlobId:(NSData*)blobId {
    DDLogVerbose(@"Sending contact photo message to %@", member.identity);
    
    NSMutableDictionary *profilePicture = [[MyIdentityStore sharedMyIdentityStore] profilePicture];
    if (!profilePicture) {
        profilePicture = [NSMutableDictionary new];
    }
    [profilePicture setValue:blobId forKey:@"BlobId"];
    [profilePicture setValue:[NSNumber numberWithUnsignedInteger:boxImageData.length] forKey:@"Size"];
    [profilePicture setValue:encryptionKey forKey:@"EncryptionKey"];
    [profilePicture setValue:[NSDate date] forKey:@"LastUpload"];
    [[MyIdentityStore sharedMyIdentityStore] setProfilePicture:profilePicture];
    
    ContactSetPhotoMessage *msg = [[ContactSetPhotoMessage alloc] init];
    msg.blobId = blobId;
    msg.size = (uint32_t)boxImageData.length;
    msg.encryptionKey = encryptionKey;
    msg.toIdentity = member.identity;
    [[MessageQueue sharedMessageQueue] enqueue:msg];
}

- (void)sendSetPhotoMessageToMember:(Contact*)member withProfilePicture:(NSMutableDictionary *)profilePicture {
    DDLogVerbose(@"Sending contact photo message to %@", member.identity);
    
    ContactSetPhotoMessage *msg = [[ContactSetPhotoMessage alloc] init];
    msg.blobId = profilePicture[@"BlobId"];
    msg.size = (uint32_t)[profilePicture[@"Size"] unsignedIntValue];
    msg.encryptionKey = profilePicture[@"EncryptionKey"];
    msg.toIdentity = member.identity;
    [[MessageQueue sharedMessageQueue] enqueue:msg];
}

- (void)sendDeletePhotoMessageToMember:(Contact *)member {
    DDLogVerbose(@"Delete contact photo message to %@", member.identity);
    
    ContactDeletePhotoMessage *msg = [[ContactDeletePhotoMessage alloc] init];
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
    
    // save to database
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performAsyncBlockAndSafe:^{
        toMember.profilePictureSended = YES;
        toMember.profilePictureUpload = [NSDate date];
    }];
    
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
