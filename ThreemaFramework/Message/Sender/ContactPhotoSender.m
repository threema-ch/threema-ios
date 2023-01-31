//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2023 Threema GmbH
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
#import "NaClCrypto.h"
#import "MyIdentityStore.h"
#import "ContactSetPhotoMessage.h"
#import "ContactDeletePhotoMessage.h"
#import "ContactRequestPhotoMessage.h"
#import "NSString+Hex.h"
#import "ActivityIndicatorProxy.h"
#import "SSLCAHelper.h"
#import "Contact.h"
#import "ThreemaError.h"
#import "ContactStore.h"
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "UserSettings.h"
#import "ServerConnector.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

#define kTimeToUploadNextBlob -60*60*24*7

@implementation ContactPhotoSender {
    EntityManager *entityManager;
    Contact *toMember;
    NSData *boxImageData;
    NSData *nonce;
    NSData *encryptionKey;
    NSMutableData *receivedData;
    NSURLConnection *uploadConnection;
    void(^onCompletion)(void);
    void(^onError)(NSError *error);
}

- (instancetype)initWith:(nonnull NSObject *)entityManagerObject {
    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Object must be type of EntityManager");

    self = [super init];
    if (self) {
        self->entityManager = (EntityManager *)entityManagerObject;
    }
    return self;
}

// MARK: - Profile picture request send

+ (void)sendProfilePictureRequest:(NSString *)toIdentity {
    DDLogVerbose(@"send profile pic request to %@", toIdentity);
    ContactRequestPhotoMessage *msg = [[ContactRequestPhotoMessage alloc] init];
    msg.toIdentity = toIdentity;
    msg.fromIdentity = [[MyIdentityStore sharedMyIdentityStore] identity];
    
    TaskDefinitionSendAbstractMessage *task = [[TaskDefinitionSendAbstractMessage alloc] initWithMessage:msg];
    TaskManager *tm = [[TaskManager alloc] init];
    [tm addObjcWithTaskDefinition:task];
}

// MARK: - Profile picture send/upload

- (Contact *)shouldSendProfilePictureToContact:(NSString *)identity {
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
    
    Contact *contact = [[entityManager entityFetcher] contactForId:identity];
    
    if (contact.isGatewayId || contact.isEchoEcho) {
        return nil;
    }
    
    // Check if another device has already sent the profile picture to this contact
    NSMutableDictionary *profilePicture = [[MyIdentityStore sharedMyIdentityStore] profilePicture];
    if (contact.profilePictureBlobID != nil && [contact.profilePictureBlobID isEqualToString:[profilePicture[@"BlobId"] base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed]]) {
        // The current blob was already sent to this contact
        return nil;
    }
    
    if (!contact.isProfilePictureSended) {
        return contact;
    }
    return nil;
}

- (void)sendProfilePicture:(AbstractMessage *)message {
    if ([message allowSendingProfile]) {
        Contact *contact = [self shouldSendProfilePictureToContact:message.toIdentity];
        if (contact) {
            // send profile picture
            [self startWithImageToMember:contact onCompletion:nil onError:nil];
        }

        ContactStore *contactStore = [ContactStore sharedContactStore];
        if ([contactStore existsProfilePictureRequestForIdentity:message.toIdentity]) {
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
            [entityManager performAsyncBlockAndSafe:^{
                toMember.profilePictureSended = YES;
                toMember.profilePictureUpload = [NSDate date];
            }];
            /* send to the specified member only */
            [self sendDeletePhotoMessageToIdentity:toMember.identity];
        }
        
        if (onCompletion) {
            onCompletion();
        }
    } else {
        // check if date is older then 2 weeks when uploading blob, when not send only the blob id in the message
        NSMutableDictionary *profilePicture = [[MyIdentityStore sharedMyIdentityStore] profilePicture];
        NSDate *lastUpload = profilePicture[@"LastUpload"];
        NSDate *blobValidDate = [NSDate dateWithTimeIntervalSinceNow:kTimeToUploadNextBlob];
        
        if (lastUpload && [lastUpload earlierDate:blobValidDate] == blobValidDate) {
            if (toMember != nil) {
                // save to database
                [entityManager performAsyncBlockAndSafe:^{
                    toMember.profilePictureSended = YES;
                    toMember.profilePictureUpload = [NSDate date];
                    NSData *blobID = profilePicture[@"BlobId"];
                    toMember.profilePictureBlobID = [blobID base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
                }];
                /* send to the specified member only */
                [self sendSetPhotoMessageToIdentity:toMember.identity withProfilePicture:profilePicture];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (onCompletion) {
                    onCompletion();
                }
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
    
    BlobURL *blobUrl = [[BlobURL alloc] initWithServerConnector:[ServerConnector sharedServerConnector] userSettings:[UserSettings sharedUserSettings]];
    Old_BlobUploader *uploader = [[Old_BlobUploader alloc] initWithBlobURL:blobUrl delegate:self];
    [uploader uploadWithBlobs:@[boxImageData] origin:BlobOriginPublic];
}

- (void)uploadCompletedWithBlobId:(NSData*)blobId {
    
    if (toMember != nil) {
        // Reload CoreData object because of concurrency problem
        [entityManager performBlock:^{
            Contact *member = [[entityManager entityFetcher] getManagedObjectById:toMember.objectID];

            /* send to the specified member only */
            [self sendSetPhotoMessageToIdentity:member.identity withBlobId:blobId];

            if (onCompletion) {
                onCompletion();
            }
        }];
    }
    else {
        if (onCompletion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onCompletion();
            });
        }
    }
}

- (void)sendSetPhotoMessageToIdentity:(nonnull NSString *)identity withBlobId:(NSData*)blobId {
    DDLogVerbose(@"Sending contact photo message to %@", identity);
    
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
    msg.toIdentity = identity;
    msg.fromIdentity = [[MyIdentityStore sharedMyIdentityStore] identity];
    
    TaskDefinitionSendAbstractMessage *task = [[TaskDefinitionSendAbstractMessage alloc] initWithMessage:msg];
    TaskManager *tm = [[TaskManager alloc] init];
    [tm addObjcWithTaskDefinition:task];
}

- (void)sendSetPhotoMessageToIdentity:(nonnull NSString *)identity withProfilePicture:(NSMutableDictionary *)profilePicture {
    DDLogVerbose(@"Sending contact photo message to %@", identity);
    
    ContactSetPhotoMessage *msg = [[ContactSetPhotoMessage alloc] init];
    msg.blobId = profilePicture[@"BlobId"];
    msg.size = (uint32_t)[profilePicture[@"Size"] unsignedIntValue];
    msg.encryptionKey = profilePicture[@"EncryptionKey"];
    msg.toIdentity = identity;
    msg.fromIdentity = [[MyIdentityStore sharedMyIdentityStore] identity];
    
    TaskDefinitionSendAbstractMessage *task = [[TaskDefinitionSendAbstractMessage alloc] initWithMessage:msg];
    TaskManager *tm = [[TaskManager alloc] init];
    [tm addObjcWithTaskDefinition:task];
}

- (void)sendDeletePhotoMessageToIdentity:(nonnull NSString *)identity {
    DDLogVerbose(@"Delete contact photo message to %@", identity);
    
    ContactDeletePhotoMessage *msg = [[ContactDeletePhotoMessage alloc] init];
    msg.toIdentity = identity;
    msg.fromIdentity = [[MyIdentityStore sharedMyIdentityStore] identity];

    TaskDefinitionSendAbstractMessage *task = [[TaskDefinitionSendAbstractMessage alloc] initWithMessage:msg];
    TaskManager *tm = [[TaskManager alloc] init];
    [tm addObjcWithTaskDefinition:task];
}

#pragma mark - BlobUploadDelegate

- (void)uploadSucceededWithBlobIds:(NSArray*)blobId {
    [ActivityIndicatorProxy stopActivity];
    
    // save to database
    [entityManager performAsyncBlockAndSafe:^{
        toMember.profilePictureSended = YES;
        toMember.profilePictureUpload = [NSDate date];
        toMember.profilePictureBlobID = [blobId[0] base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    }];
    
    DDLogVerbose(@"Blob ID: %@", blobId[0]);
    [self uploadCompletedWithBlobId:blobId[0]];
}

- (void)uploadFailed {
    DDLogError(@"Blob upload failed");
    
    [ActivityIndicatorProxy stopActivity];
    
    if (onError) {
        onError([ThreemaError threemaError:@"Blob upload failed"]);
    }
}

- (void)uploadDidCancel { }

- (void)uploadProgress:(NSNumber *)progress { }

- (BOOL)uploadShouldCancel { 
    return NO;
}

@end
