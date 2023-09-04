//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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

#import "FileMessageDecoder.h"
#import "FileMessageKeys.h"
#import "NSString+Hex.h"
#import "FileMessageEntity.h"
#import "EntityCreator.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "PinnedHTTPSURLLoader.h"
#import "ThreemaError.h"
#import "NaClCrypto.h"
#import "ServerConnector.h"
#import "UserSettings.h"
#import "ActivityIndicatorProxy.h"
#import "NonceHasher.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
typedef void (^CompletionBlock)(BaseMessage *message);
typedef void (^ErrorBlock)(NSError *err);

@interface FileMessageDecoder ()

@property Conversation *conversation;
@property ContactEntity *sender;
@property AbstractMessage *boxMessage;
@property NSDictionary *json;
@property NSData *jsonData;

@property (copy) CompletionBlock onCompletion;
@property (copy) ErrorBlock onError;

@end

@implementation FileMessageDecoder {
    BOOL isReflectedMessage;
    int timeoutDownloadThumbnail;
    EntityManager *entityManager;
}

+ (void)decodeMessageFromBox:(nonnull BoxFileMessage *)message sender:(nullable ContactEntity *)sender conversation:(nonnull Conversation *)conversation isReflectedMessage:(BOOL)isReflected timeoutDownloadThumbnail:(int)timeout entityManager:(nonnull NSObject *)entityManagerObject onCompletion:(void (^)(BaseMessage *))onCompletion onError:(void (^)(NSError *))onError {
    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Object must be type of EntityManager");

    FileMessageDecoder *decoder = [FileMessageDecoder fileMessageDecoderOnCompletion:onCompletion onError:onError sender:sender conversation:conversation timeoutDownloadThumbnail:timeout];

    decoder->isReflectedMessage = isReflected;
    decoder->entityManager = (EntityManager *)entityManagerObject;
    [decoder decodeMessageFromBox:message];
}

+ (void)decodeGroupMessageFromBox:(nonnull GroupFileMessage *)message sender:(nullable ContactEntity *)sender conversation:(nonnull Conversation *)conversation isReflectedMessage:(BOOL)isReflected timeoutDownloadThumbnail:(int)timeout entityManager:(nonnull NSObject *)entityManagerObject onCompletion:(void (^)(BaseMessage *))onCompletion onError:(void (^)(NSError *))onError {
    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Object must be type of EntityManager");

    FileMessageDecoder *decoder = [FileMessageDecoder fileMessageDecoderOnCompletion:onCompletion onError:onError sender:sender conversation:conversation timeoutDownloadThumbnail:timeout];
    
    decoder->isReflectedMessage = isReflected;
    decoder->entityManager = (EntityManager *)entityManagerObject;
    [decoder decodeGroupMessageFromBox:message];
}

+ (NSString *)decodeFilenameFromBox:(BoxFileMessage *)message {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    if ([decoder prepareJson:message.jsonData] == NO) {
        return nil;
    }
    
    return [decoder.json objectForKey: JSON_FILE_KEY_FILENAME];
}

+ (NSString *)decodeGroupFilenameFromBox:(GroupFileMessage *)message {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    if ([decoder prepareJson:message.jsonData] == NO) {
        return nil;
    }
    
    return [decoder.json objectForKey: JSON_FILE_KEY_FILENAME];
}

+ (NSString *)decodeFileCaptionFromBox:(BoxFileMessage *)message {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    if ([decoder prepareJson:message.jsonData] == NO) {
        return nil;
    }
    
    return [decoder.json objectForKey: JSON_FILE_KEY_DESCRIPTION];
}

+ (NSString *)decodeGroupFileCaptionFromBox:(GroupFileMessage *)message {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    if ([decoder prepareJson:message.jsonData] == NO) {
        return nil;
    }
    
    return [decoder.json objectForKey: JSON_FILE_KEY_DESCRIPTION];
}

#pragma mark - private

+ (instancetype)fileMessageDecoderOnCompletion:(void(^)(BaseMessage *message))onCompletion onError:(void(^)(NSError *err))onError sender:(nullable ContactEntity *)sender conversation:(nonnull Conversation *)conversation timeoutDownloadThumbnail:(int)timeoutDownloadThumbnail {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    decoder.onCompletion = onCompletion;
    decoder.onError = onError;

    decoder.sender = sender;
    decoder.conversation = conversation;
    decoder->timeoutDownloadThumbnail = timeoutDownloadThumbnail;

    return decoder;
}

- (void)decodeMessageFromBox:(BoxFileMessage *)message {
    if ([self prepareJson:message.jsonData] == NO) {
        return;
    }

    [self handleMessage:message];
}

- (void)decodeGroupMessageFromBox:(GroupFileMessage *)message {
    if ([self prepareJson:message.jsonData] == NO) {
        return;
    }
    
    [self handleMessage:message];
}

- (void)handleMessage:(AbstractMessage *)message {
    _boxMessage = message;

    FileMessageEntity *fileMessageEntity = [self createDBMessage];
    if (fileMessageEntity) {
        [self fetchThumbnail:fileMessageEntity];
    }
}

- (BOOL)prepareJson:(NSData *)data {
    NSError *error;
    _json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (_json == nil) {
        DDLogError(@"Error parsing json %@, %@", error, [error userInfo]);
        if (_onError != nil) {
            _onError([ThreemaError threemaError:@"Error parsing file message json data"]);
        }
        return NO;
    }
    
    _jsonData = data;
    return YES;
}

- (void)fetchThumbnail:(FileMessageEntity *)fileMessageEntity {
    __block NSManagedObjectID *objectID;
    __block NSData *blobID;
    __block BlobOrigin blobOrigin;
    __block BlobOrigin blobOriginForDone = BlobOriginPublic;
    __block BOOL isNotGroupMessage = YES;

    [entityManager performBlockAndWait:^{
        objectID = fileMessageEntity.objectID;
        blobID = fileMessageEntity.blobThumbnailId;
        blobOrigin = fileMessageEntity.blobOrigin;
        isNotGroupMessage = fileMessageEntity.conversation.groupId == nil;

        if (isNotGroupMessage) {
            blobOriginForDone = fileMessageEntity.blobOrigin;
        }
        else if ([[UserSettings sharedUserSettings] enableMultiDevice]) {
            blobOriginForDone = BlobOriginLocal;
        }
    }];

    if (blobID) {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        dispatch_queue_t dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

        [ActivityIndicatorProxy startActivity];
        
        BlobURL *blobUrl = [[BlobURL alloc] initWithServerConnector:[ServerConnector sharedServerConnector] userSettings:[UserSettings sharedUserSettings] queue:dispatchQueue];
        BlobDownloader *downloader = [[BlobDownloader alloc] initWithBlobURL:blobUrl queue:dispatchQueue];
        [downloader downloadWithBlobID:blobID origin:blobOrigin completion:^(NSData *data, NSError *error) {
            if (data != nil && error == nil) {
                NSString *encryptionKeyHex = [_json objectForKey: JSON_FILE_KEY_ENCRYPTION_KEY];
                NSData *encryptionKey = [encryptionKeyHex decodeHex];

                /* Decrypt the box */
                NSData *decodedData = [[NaClCrypto sharedCrypto] symmetricDecryptData:data withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_2 length:sizeof(kNonce_2) freeWhenDone:NO]];
                if (decodedData == nil) {
                    DDLogError(@"Could not decode thumbnail data");
                }

                [self updateDBMessageWithThumbnail:decodedData objectID:objectID];

                if (isNotGroupMessage) {
                    [downloader markDownloadDoneFor:blobID origin:blobOriginForDone];
                }
            }
            else {
                DDLogError(@"Could not download thumbnail for file message %@", error.localizedDescription);
                [self updateDBMessageWithThumbnail:nil objectID:objectID];
            }
            
            dispatch_semaphore_signal(sema);
        }];

        dispatch_time_t timeout;
        
        // Set timeout 20s if App not active or its notification extension
        if (self->timeoutDownloadThumbnail > 0) {
            // Wait for 20 seconds (20 * 10^9 ns) to downloading thumbnail
            timeout = dispatch_time(DISPATCH_TIME_NOW, self->timeoutDownloadThumbnail * NSEC_PER_SEC);
        }
        else {
            timeout = DISPATCH_TIME_FOREVER;
        }

        BOOL timedOut = dispatch_semaphore_wait(sema, timeout);
        
        if (timedOut) {
            [self updateDBMessageWithThumbnail:nil objectID:objectID];
        }

        [ActivityIndicatorProxy stopActivity];
    } else {
        [self updateDBMessageWithThumbnail:nil objectID:objectID];
    }
}

- (FileMessageEntity *)createDBMessage {
    __block FileMessageEntity *fileMessageEntity = (FileMessageEntity *)[entityManager getOrCreateMessageFor:_boxMessage sender:_sender conversation:_conversation thumbnail:nil];

    [entityManager performSyncBlockAndSafe:^{
        GroupManager *groupManager = [[GroupManager alloc] initWithEntityManager:entityManager];
        Group *group = [groupManager getGroupWithConversation:_conversation];

        // Blob origin for download
        BOOL isOutgoingMessage = [_boxMessage.fromIdentity isEqualToString:[[MyIdentityStore sharedMyIdentityStore] identity]];
        BOOL isLocalOrigin = (group && group.isNoteGroup) || (isReflectedMessage && isOutgoingMessage);
        fileMessageEntity.blobOrigin = isLocalOrigin ? BlobOriginLocal : BlobOriginPublic;

        NSString *blobHex = [_json objectForKey: JSON_FILE_KEY_FILE_BLOB];
        fileMessageEntity.blobId = [blobHex decodeHex];
        
        NSString *thumbnailBlobHex = [_json objectForKey: JSON_FILE_KEY_THUMBNAIL_BLOB];
        if (thumbnailBlobHex) {
            fileMessageEntity.blobThumbnailId = [thumbnailBlobHex decodeHex];
        }
        
        NSString *encryptionKeyHex = [_json objectForKey: JSON_FILE_KEY_ENCRYPTION_KEY];
        fileMessageEntity.encryptionKey = [encryptionKeyHex decodeHex];
        
        fileMessageEntity.mimeType = [_json objectForKey: JSON_FILE_KEY_MIMETYPE];
        
        fileMessageEntity.fileSize = [_json objectForKey: JSON_FILE_KEY_FILESIZE];
        
        NSNumber *type = [_json objectForKey: JSON_FILE_KEY_TYPE];
        if (type == nil) {
            type = [_json objectForKey: JSON_FILE_KEY_TYPE_DEPRECATED];
            if (type == nil) {
                fileMessageEntity.type = @0;
            }
        } else {
            fileMessageEntity.type = type;
        }
        
        NSString *filename = [_json objectForKey: JSON_FILE_KEY_FILENAME];
        if (filename) {
            fileMessageEntity.fileName = filename;
        }
        
        NSString *caption = [_json objectForKey: JSON_FILE_KEY_DESCRIPTION];
        if (caption) {
            fileMessageEntity.caption = caption;
        }
        
        fileMessageEntity.json = [[NSString alloc] initWithData:_jsonData encoding:NSUTF8StringEncoding];
    }];

    return fileMessageEntity;
}

- (void)updateDBMessageWithThumbnail:(nullable NSData *)thumbnailData objectID:(nonnull NSManagedObjectID *)objectID {
    [entityManager performAsyncBlockAndSafe:^{
        FileMessageEntity *msg = [[entityManager entityFetcher] existingObjectWithID:objectID];

        if (msg && msg.thumbnail == nil && thumbnailData) {
            ImageData *thumbnail = [entityManager.entityCreator imageData];
            thumbnail.data = thumbnailData;
            
            // load image to determine size
            UIImage *thumbnailImage = [UIImage imageWithData:thumbnailData];
            thumbnail.width = [NSNumber numberWithInt:thumbnailImage.size.width];
            thumbnail.height = [NSNumber numberWithInt:thumbnailImage.size.height];
            
            msg.thumbnail = thumbnail;
        }

        _onCompletion(msg);
    }];
}

@end
