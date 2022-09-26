//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import "BlobMessageLoader.h"
#import "ProtocolDefines.h"
#import "NaClCrypto.h"
#import "MessageSender.h"
#import "ThreemaError.h"
#import "PinnedHTTPSURLLoader.h"
#import "UserSettings.h"
#import "MediaConverter.h"
#import "BundleUtil.h"
#import "FileMessageEntity.h"
#import "ImageMessageEntity.h"
#import "ValidationLogger.h"
#import "Conversation.h"
#import "UTIConverter.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface BlobMessageLoader () <HTTPSURLLoaderDelegate>

@end

@implementation BlobMessageLoader {
    NSManagedObjectID *messageObjectID;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _entityManager = [[EntityManager alloc] init];
    }
    return self;
}

- (void)startWithMessage:(BaseMessage<BlobData> *)message onCompletion:(void (^)(BaseMessage<BlobData> *loadedMessage))onCompletion onError:(void (^)(NSError *error))onError {
    self->messageObjectID = message.objectID;

    NSData *blobData = [message blobGetData];
    if (blobData != nil) {
        onCompletion(message);
        return;
    }
    
    NSData *blobId = [message blobGetId];
    if (blobId == nil) {
        DDLogWarn(@"Missing blob ID or encryption key!");
        onError([ThreemaError threemaError:[BundleUtil localizedStringForKey:@"media_file_not_found"]]);
        return;
    }

    NSData *encryptionKey = [message blobGetEncryptionKey];

    if (encryptionKey == nil) {
        // handle image message backward compatibility
        if ([message isKindOfClass:[ImageMessageEntity class]]) {
            if (((ImageMessageEntity *)message).imageNonce == nil) {
                DDLogWarn(@"Missing image encryption key or nonce!");
                return;
            }
        } else {
            DDLogWarn(@"Missing encryption key!");
            return;
        }
    }

    NSNumber *progress = [message blobGetProgress];
    if (progress != nil) {
        DDLogWarn(@"Blob download already in progress");
        return;
    }

    PinnedHTTPSURLLoader *loader = [[PinnedHTTPSURLLoader alloc] init];
    loader.delegate = self;
    
    BOOL localOrigin = false;
    if ([message isKindOfClass:FileMessageEntity.class]) {
        FileMessageEntity *fileMessageEntity = (FileMessageEntity *)message;
        if (fileMessageEntity.origin.intValue == 1) {
            localOrigin = true;
        }
    }
    
    // Set progress to 0 before starting the request to be sure this request will not called multiple times
    [_entityManager performSyncBlockAndSafe:^{
        BaseMessage<BlobData> *bmsg = [_entityManager.entityFetcher getManagedObjectById:messageObjectID];
        [bmsg blobUpdateProgress:[NSNumber numberWithFloat:0]];
    }];
    
    [loader startWithBlobId:blobId localOrigin:localOrigin onCompletion:^(NSData *data) {
        [_entityManager performSyncBlockAndSafe:^{
            BaseMessage<BlobData> *msg = [_entityManager.entityFetcher getManagedObjectById:messageObjectID];

            if ([msg wasDeleted]) {
                return;
            }

            NSData *decryptedData = [self decryptData:data forMessage:msg];
            if (decryptedData == nil) {
                msg.sendFailed = [NSNumber numberWithBool:YES];
                [msg blobUpdateProgress:nil];

                onError([ThreemaError threemaError:@"Blob data decryption failed"]);
                return;
            }

            [self updateDBObject:msg with:decryptedData];

            if (msg.conversation.groupId == nil || localOrigin) {
                [MessageSender markBlobAsDone:blobId localOrigin:localOrigin];
            }

            DDLogInfo(@"Blob successfully downloaded (%lu bytes)", (unsigned long)data.length);

            onCompletion(msg);
        }];
    } onError:^(NSError *error) {
        [[ValidationLogger sharedValidationLogger] logString:error.description];

        [_entityManager performSyncBlockAndSafe:^{
            BaseMessage<BlobData> *msg = [_entityManager.entityFetcher getManagedObjectById:messageObjectID];
            if ([msg wasDeleted] == NO) {
                // Only set failed state if blobData is nil
                if (msg.blobGetData == nil) {
                    [msg blobSetError:YES];
                }
                [msg blobUpdateProgress:nil];
            }
        }];

        onError([ThreemaError threemaError:[BundleUtil localizedStringForKey:@"media_file_not_found"]]);
    }];
}


- (NSData *)decryptData:(NSData *)data forMessage:(BaseMessage<BlobData> *)message {
    NSData *decryptedData = nil;
    
    @try {
        decryptedData = [[NaClCrypto sharedCrypto] symmetricDecryptData:data withKey:[message blobGetEncryptionKey] nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
    } @catch (NSException *exception) {
        DDLogError(@"Blob decryption failed: %@", [exception description]);
    }
    
    return decryptedData;
}

- (void)updateDBObject:(BaseMessage<BlobData> *)message with:(NSData *)data {
    [message blobSetData:data];
    [message blobUpdateProgress:nil];
    message.sendFailed = [NSNumber numberWithBool:NO];

    /* Add to photo library */
    if ([UserSettings sharedUserSettings].autoSaveMedia && [message isKindOfClass:FileMessageEntity.class]) {
        FileMessageEntity *fileMessageEntity = (FileMessageEntity *)message;
        NSString *filename = [FileUtility getTemporaryFileName];
        __block NSURL *tmpFileUrl = [fileMessageEntity tmpURL:filename];
        if (tmpFileUrl == nil) {
            DDLogError(@"No tmpFileUrl to export to and thus unable to save to photos library");
            return;
        }
        [fileMessageEntity exportDataToURL:tmpFileUrl];

        BOOL isVideo = [UTIConverter isVideoMimeType:fileMessageEntity.mimeType] || [UTIConverter isMovieMimeType:fileMessageEntity.mimeType];
        BOOL isImage = [UTIConverter isImageMimeType:fileMessageEntity.mimeType];
        BOOL isSticker = [fileMessageEntity.type  isEqual: @2];
        if (isVideo == true || (isImage == true && isSticker == false)) {
            [[AlbumManager shared] saveWithUrl:tmpFileUrl isVideo:isVideo completionHandler:^(__unused BOOL success) {
                if (tmpFileUrl) {
                    [[NSFileManager defaultManager] removeItemAtURL:tmpFileUrl error:nil];
                    tmpFileUrl = nil;
                }
            }];
        }
    }
}

#pragma mark HTTPSURLLoaderDelegate

- (BOOL)httpsLoaderShouldCancel {
    __block BOOL wasDeleted = NO;

    [_entityManager performBlockAndWait:^{
        BaseMessage<BlobData> *msg = [_entityManager.entityFetcher getManagedObjectById:messageObjectID];
        if ([msg wasDeleted]) {
            wasDeleted = YES;
        }
    }];

    return wasDeleted;
}

- (void)httpsLoaderReceivedData:(NSData *)totalData {
    [_entityManager performSyncBlockAndSafe:^{
        BaseMessage<BlobData> *msg = [_entityManager.entityFetcher getManagedObjectById:messageObjectID];
        if ([msg wasDeleted]) {
            return;
        }

        [msg blobUpdateProgress:[NSNumber numberWithFloat:totalData.length / [msg blobGetSize].floatValue]];
    }];
}

@end
